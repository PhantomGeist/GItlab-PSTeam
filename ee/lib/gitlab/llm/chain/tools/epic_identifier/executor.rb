# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module EpicIdentifier
          class Executor < Identifier
            RESOURCE_NAME = 'epic'
            NAME = "EpicIdentifier"
            HUMAN_NAME = 'Epic Search'
            DESCRIPTION = 'Useful tool when you need to identify a specific epic. ' \
                          'Do not use this tool if you have already identified the epic. ' \
                          'In this context, word `epic` means high-level building block in GitLab that encapsulates ' \
                          'high-level plans and discussions. Epic can contain multiple issues. ' \
                          'Action Input for this tool should be the original question or epic identifier.'

            EXAMPLE =
              <<~PROMPT
                Question: Please identify the author of &epic_identifier epic
                Picked tools: First: "EpicIdentifier" tool, second: "ResourceReader" tool.
                Reason: You have access to the same resources as user who asks a question.
                  There is epic identifier in the question, so you need to use "EpicIdentifier" tool.
                  Once the epic is identified, you should use "ResourceReader" tool to fetch relevant information
                  about the resource. Based on this information you can present final answer.
              PROMPT

            PROVIDER_PROMPT_CLASSES = {
              anthropic: ::Gitlab::Llm::Chain::Tools::EpicIdentifier::Prompts::Anthropic,
              vertex_ai: ::Gitlab::Llm::Chain::Tools::EpicIdentifier::Prompts::VertexAi
            }.freeze

            GROUP_REGEX = {
              'url' => ::Epic.link_reference_pattern,
              'reference' => ::Epic.reference_pattern
            }.freeze

            # our template
            PROMPT_TEMPLATE = [
              Utils::Prompt.as_system(
                <<~PROMPT
                You can fetch information about a resource called: an epic.
                An epic can be referenced by url or numeric IDs preceded by symbol.
                An epic can also be referenced by a GitLab reference.
                A GitLab reference ends with a number preceded by the delimiter & and contains one or more /.
                ResourceIdentifierType can only be one of [current, iid, url, reference]
                ResourceIdentifier can be number, url. If ResourceIdentifier is not a number or a url
                use "current".
                When you see a GitLab reference, ResourceIdentifierType should be reference.

                Make sure the response is a valid JSON. The answer should be just the JSON without any other commentary!
                References in the given question to the current epic can be also for example "this epic" or "that epic",
                referencing the epic that the user currently sees.
                Question: (the user question)
                Response (follow the exact JSON response):
                ```json
                {
                  "ResourceIdentifierType": <ResourceIdentifierType>
                  "ResourceIdentifier": <ResourceIdentifier>
                }
                ```

                Examples of epic reference identifier:

                Question: The user question or request may include https://some.host.name/some/long/path/-/epics/410692
                Response:
                ```json
                {
                  "ResourceIdentifierType": "url",
                  "ResourceIdentifier": "https://some.host.name/some/long/path/-/epics/410692"
                }
                ```

                Question: the user question or request may include: &12312312
                Response:
                ```json
                {
                  "ResourceIdentifierType": "iid",
                  "ResourceIdentifier": 12312312
                }
                ```

                Question: the user question or request may include long/groups/path&12312312
                Response:
                ```json
                {
                  "ResourceIdentifierType": "reference",
                  "ResourceIdentifier": "long/groups/path&12312312"
                }
                ```

                Question: Summarize the current epic
                Response:
                ```json
                {
                  "ResourceIdentifierType": "current",
                  "ResourceIdentifier": "current"
                }
                ```

                Begin!
                PROMPT
              ),
              Utils::Prompt.as_assistant("%<suggestions>s"),
              Utils::Prompt.as_user("Question: %<input>s")
            ].freeze

            private

            def prompt_template
              PROMPT_TEMPLATE
            end

            def by_iid(resource_identifier)
              return unless group_from_context

              epics = group_from_context.epics.iid_in(resource_identifier.to_i)

              return epics.first if epics.one?
            end

            def extract_resource(text, _type)
              project = extract_project
              return unless project

              extractor = Gitlab::ReferenceExtractor.new(project, context.current_user)
              extractor.analyze(text, {})
              epics = extractor.epics

              epics.first if epics.one?
            end

            def extract_project
              return projects_from_context.first unless projects_from_context.blank?

              # Epics belong to a group. The `ReferenceExtractor` expects a `project`
              # but does not use it for the extraction of epics.
              context.current_user.authorized_projects.first
            end

            def resource_name
              RESOURCE_NAME
            end
          end
        end
      end
    end
  end
end
