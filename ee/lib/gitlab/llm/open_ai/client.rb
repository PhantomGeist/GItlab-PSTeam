# frozen_string_literal: true

require 'openai'

module Gitlab
  module Llm
    module OpenAi
      class Client
        include ::Gitlab::Llm::Concerns::ExponentialBackoff
        include ::Gitlab::Llm::Concerns::EventTracking

        InputModerationError = Class.new(StandardError)
        OutputModerationError = Class.new(StandardError)

        def initialize(user, request_timeout: nil, tracking_context: {})
          @user = user
          @request_timeout = request_timeout
          @tracking_context = tracking_context
          @logger = Gitlab::Llm::Logger.build
        end

        def chat(content:, moderated: nil, **options)
          request(
            endpoint: :chat,
            moderated: warn_if_moderated_unset(moderated, default: true),
            parameters: Options.new.chat(content: content, **options)
          )
        end

        # messages: an array with `role` and `content` a keys.
        # the value of `role` should be one of GPT_ROLES
        # this needed to pass back conversation history
        def messages_chat(messages:, moderated: nil, **options)
          request(
            endpoint: :chat,
            moderated: warn_if_moderated_unset(moderated, default: true),
            parameters: Options.new.messages_chat(messages: messages, **options)
          )
        end

        def completions(prompt:, moderated: nil, **options)
          request(
            endpoint: :completions,
            moderated: warn_if_moderated_unset(moderated, default: true),
            parameters: Options.new.completions(prompt: prompt, **options)
          )
        end

        def edits(input:, instruction:, moderated: nil, **options)
          request(
            endpoint: :edits,
            moderated: warn_if_moderated_unset(moderated, default: true),
            parameters: Options.new.edits(input: input, instruction: instruction, **options)
          )
        end

        def embeddings(input:, moderated: nil, **options)
          request(
            endpoint: :embeddings,
            moderated: warn_if_moderated_unset(moderated, default: false),
            parameters: Options.new.embeddings(input: input, **options)
          )
        end

        def moderations(input:, **options)
          request(
            endpoint: :moderations,
            moderated: false,
            parameters: Options.new.moderations(input: input, **options)
          )
        end

        private

        attr_reader :user, :request_timeout, :logger, :tracking_context

        def client
          @client ||= OpenAI::Client.new(access_token: access_token, request_timeout: request_timeout)
        end

        def enabled?
          access_token.present? &&
            (Feature.enabled?(:openai_experimentation, user) || Feature.enabled?(:ai_global_switch, type: :ops))
        end

        def access_token
          @token ||= ::Gitlab::CurrentSettings.openai_api_key
        end

        def warn_if_moderated_unset(moderated, default:)
          return moderated unless moderated.nil?

          msg = "The `moderated` argument is not set, and defaults to `#{default}`. " \
                "Please update this code to explicitly pass this argument"
          # Reject stack entries related to this class to reach client code
          regexp = /#{__FILE__}|exponential_backoff.rb|circuit_breaker.rb/
          stacktrace = caller_locations.reject { |loc| loc.to_s =~ regexp }
          ActiveSupport::Deprecation.warn(msg, stacktrace)

          default
        end

        # @param [Symbol] endpoint - OpenAI endpoint to call
        # @param [Boolean, Symbol] moderated - Whether to moderate the input and/or output.
        #   `true` - moderate both,
        #   `false` - moderation none,
        #   `:input` - moderate only input,
        #   `:output` - moderate only output
        # @param [Hash] options - Options to pass to the OpenAI client
        def request(endpoint:, moderated:, **options)
          return unless enabled?

          logger.info(message: "Performing request to OpenAI", endpoint: endpoint)

          moderate!(:input, moderation_input(endpoint, options)) if should_moderate?(:input, moderated)

          response = retry_with_exponential_backoff do
            client.public_send(endpoint, **options) # rubocop:disable GitlabSecurity/PublicSend
          end

          logger.debug(message: "Received response from OpenAI", response: response)

          track_cost(endpoint, response.parsed_response&.dig('usage'))

          if should_moderate?(:output, moderated)
            moderate!(:output, moderation_output(endpoint, response.parsed_response))
          end

          response
        end

        def track_cost(endpoint, usage_data)
          return unless usage_data

          track_cost_metric("#{endpoint}/prompt", usage_data['prompt_tokens'])
          track_cost_metric("#{endpoint}/completion", usage_data['completion_tokens'])

          track_prompt_size(usage_data['prompt_tokens'])
          track_response_size(usage_data['completion_tokens'])
        end

        def track_cost_metric(context, amount)
          return unless amount

          cost_metric.increment(
            {
              vendor: 'open_ai',
              item: context,
              unit: 'tokens',
              feature_category: ::Gitlab::ApplicationContext.current_context_attribute(:feature_category)
            },
            amount
          )
        end

        def cost_metric
          @cost_metric ||= Gitlab::Metrics.counter(
            :gitlab_cloud_cost_spend_entry_total,
            'Number of units spent per vendor entry'
          )
        end

        def should_moderate?(type, moderation_value)
          return false if moderation_value == false
          return true if moderation_value == true
          return true if type == :input && moderation_value == :input
          return true if type == :output && moderation_value == :output

          false
        end

        # @param [Symbol] type - Type of text to moderate, input or output
        # @param [String] text - Text to moderate
        def moderate!(type, text)
          return unless text.present?

          flagged = moderations(input: text)
            .parsed_response
            &.dig('results')
            &.any? { |r| r['flagged'] }

          return unless flagged

          error_type = type == :input ? InputModerationError : OutputModerationError
          error_message = "Provided #{type} violates OpenAI's Content Policy"

          raise(error_type, error_message)
        end

        # rubocop:disable CodeReuse/ActiveRecord
        def moderation_input(endpoint, options)
          case endpoint
          when :chat
            options.dig(:parameters, :messages).pluck(:content)
          when :completions
            options.dig(:parameters, :prompt)
          when :edits, :embeddings
            options.dig(:parameters, :input)
          end
        end

        def moderation_output(endpoint, parsed_response)
          case endpoint
          when :chat
            parsed_response&.dig('choices')&.pluck('message')&.pluck('content')&.map { |str| str.delete('\"') }
          when :edits, :completions
            parsed_response&.dig('choices')&.pluck('text')
          end
        end
        # rubocop:enable CodeReuse/ActiveRecord
      end
    end
  end
end
