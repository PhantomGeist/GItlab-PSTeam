# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Agents
        module ZeroShot
          class Executor
            include Gitlab::Utils::StrongMemoize
            include Concerns::AiDependent

            attr_reader :tools, :user_input, :context, :response_handler
            attr_accessor :iterations

            AGENT_NAME = 'GitLab Duo Chat'
            MAX_ITERATIONS = 10
            RESPONSE_TYPE_TOOL = 'tool'

            PROVIDER_PROMPT_CLASSES = {
              anthropic: ::Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic,
              vertex_ai: ::Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::VertexAi
            }.freeze

            # @param [String] user_input - a question from a user
            # @param [Array<Tool>] tools - an array of Tools defined in the tools module.
            # @param [GitlabContext] context - Gitlab context containing useful context information
            # @param [ResponseService] response_handler - Handles returning the response to the client
            # @param [ResponseService] stream_response_handler - Handles streaming chunks to the client
            def initialize(user_input:, tools:, context:, response_handler:, stream_response_handler: nil)
              @user_input = user_input
              @tools = tools
              @context = context
              @iterations = 0
              @logger = Gitlab::Llm::Logger.build
              @response_handler = response_handler
              @stream_response_handler = stream_response_handler
            end

            def execute
              MAX_ITERATIONS.times do
                thought = execute_streamed_request

                answer = Answer.from_response(response_body: "Thought: #{thought}", tools: tools, context: context)

                return answer if answer.is_final?

                options[:agent_scratchpad] << "\nThought: #{answer.suggestions}"
                options[:agent_scratchpad] << answer.content.to_s

                tool_class = answer.tool

                picked_tool_action(tool_class)

                tool = tool_class.new(
                  context: context,
                  options: {
                    input: user_input,
                    suggestions: options[:agent_scratchpad]
                  },
                  stream_response_handler: stream_response_handler
                )

                tool_answer = tool.execute

                # track a successful tool usage, to avoid cycling through same tools multiple times
                context.tools_used << tool_class

                # detect tool cycling for specific types of questions
                logger.info(message: "Tool cycling detected") if tools_cycle?

                return tool_answer if tool_answer.is_final?

                options[:agent_scratchpad] << "Observation: #{tool_answer.content}\n"
              end

              Answer.default_final_answer(context: context)
            rescue Net::ReadTimeout => error
              Gitlab::ErrorTracking.track_exception(error)
              Answer.error_answer(
                context: context,
                content: _("GitLab Duo didn't respond. Try again? If it fails again, your request might be too large.")
              )
            end

            private

            def execute_streamed_request
              streamed_answer = StreamedAnswer.new

              request do |content|
                next unless stream_response_handler

                chunk = streamed_answer.next_chunk(content)

                if chunk
                  stream_response_handler.execute(
                    response: Gitlab::Llm::Chain::PlainResponseModifier.new(content),
                    options: {
                      chunk_id: chunk[:id]
                    }
                  )
                end
              end
            end

            def tools_cycle?
              context.tools_used.size != context.tools_used.uniq.size
            end

            attr_reader :logger, :stream_response_handler

            # This method should not be memoized because the input variables change over time
            def base_prompt
              Utils::Prompt.no_role_text(PROMPT_TEMPLATE, options)
            end

            def options
              @options ||= {
                tool_names: tools.map { |tool_class| tool_class::Executor::NAME }.join(', '),
                tools_definitions: tools.map.with_index do |tool_class, idx|
                  "#{idx + 1}. #{tool_class::Executor::NAME}: #{tool_class::Executor::DESCRIPTION}" \
                    "\n" \
                    "Example of usage: #{tool_class::Executor.full_example}" \
                end.join("\n"),
                user_input: user_input,
                agent_scratchpad: +"",
                conversation: conversation,
                prompt_version: prompt_version,
                current_code: current_code,
                resources: available_resources_names
              }
            end

            def picked_tool_action(tool_class)
              logger.info(message: "Picked tool", tool: tool_class.to_s)

              response_handler.execute(
                response: Gitlab::Llm::Chain::ToolResponseModifier.new(tool_class),
                options: { role: ::Gitlab::Llm::AiMessage::ROLE_SYSTEM,
                           type: RESPONSE_TYPE_TOOL }
              )

              # We need to stream the response for clients that already migrated to use `ai_action` and no longer
              # use `resource_id` as an identifier. Once streaming is enabled and all clients migrated, we can
              # remove the `response_handler` call above.
              return unless stream_response_handler

              stream_response_handler.execute(
                response: Gitlab::Llm::Chain::ToolResponseModifier.new(tool_class),
                options: {
                  role: ::Gitlab::Llm::ChatMessage::ROLE_SYSTEM,
                  type: RESPONSE_TYPE_TOOL
                }
              )
            end

            def available_resources_names
              tools.filter_map do |tool_class|
                tool_class::Executor::RESOURCE_NAME.pluralize if tool_class::Executor::RESOURCE_NAME.present?
              end.join(', ')
            end
            strong_memoize_attr :available_resources_names

            def prompt_version
              PROMPT_TEMPLATE
            end

            def last_conversation
              ChatStorage.new(context.current_user).last_conversation
            end
            strong_memoize_attr :last_conversation

            def conversation
              # include only messages with successful response and reorder
              # messages so each question is followed by its answer
              by_request = last_conversation
                .reject { |message| message.errors.present? }
                .group_by(&:request_id)
                .select { |_uuid, messages| messages.size > 1 }

              by_request.values.sort_by { |messages| messages.first.timestamp }.flatten
            end

            def current_code
              blob = @context.extra_resource[:blob]
              return "" unless blob

              provider_prompt_class.current_code_prompt(blob)
            end

            PROMPT_TEMPLATE = [
              Utils::Prompt.as_system(
                <<~PROMPT
                  Answer the question as accurate as you can.

                  You have access only to the following tools:
                  %<tools_definitions>s
                  Consider every tool before making a decision.
                  Identifying resource mustn't be the last step.
                  Ensure that your answer is accurate and contain only information directly supported
                  by the information retrieved using provided tools.

                  You must always use the following format:
                  Question: the input question you must answer
                  Thought: you should always think about what to do
                  Action: the action to take, should be one tool from this list or an direct answer (then use DirectAnswer as action): [%<tool_names>s]
                  Action Input: the input to the action needs to be provided for every action that uses a tool
                  Observation: the result of the actions. If the Action is DirectAnswer never write an Observation, but remember that you're still #{AGENT_NAME}.

                  ... (this Thought/Action/Action Input/Observation sequence can repeat N times)

                  Thought: I know the final answer.
                  Final Answer: the final answer to the original input question.

                  When concluding your response, provide the final answer as "Final Answer:" as soon as the answer is recognized.
                  %<current_code>s
                  If no tool is needed, give a final answer with "Action: DirectAnswer" for the Action parameter and skip writing an Observation.

                  You have access to the following GitLab resources: %<resources>s.
                  At the moment, you do not have access to the following GitLab resources: Merge Requests, Pipelines, Vulnerabilities.
                  When there is no available tool, not enough context or resource is not available to accurately answer the question you must tell it to the user using phrase:
                  "The question you are asking requires data that is not available to GitLab Duo Chat. Please share your feedback below.".
                  Avoid asking for more details if you cannot provide an answer anyway.
                  Ask user to leave feedback.

                  Begin!
                PROMPT
              ),
              Utils::Prompt.as_user("Question: %<user_input>s"),
              Utils::Prompt.as_assistant("Assistant: %<agent_scratchpad>s"),
              Utils::Prompt.as_assistant("Thought: ")
            ].freeze
          end
        end
      end
    end
  end
end
