# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module SummarizeComments
          module Prompts
            class VertexAi
              TOTAL_MODEL_TOKEN_LIMIT = 8192
              # leave a 10% for cases where 1 token does not exactly match to 4 characters
              INPUT_TOKEN_LIMIT = (TOTAL_MODEL_TOKEN_LIMIT * 0.9).to_i.freeze
              # approximate that one token is ~4 characters
              INPUT_CONTENT_LIMIT = INPUT_TOKEN_LIMIT * 4
              OUTPUT_TOKEN_LIMIT = 1024

              def self.prompt(options)
                prompt = Utils::Prompt.no_role_text(
                  ::Gitlab::Llm::Chain::Tools::SummarizeComments::Executor::PROMPT_TEMPLATE, options
                )

                {
                  prompt: prompt,
                  options: {
                    max_output_tokens: OUTPUT_TOKEN_LIMIT
                  }
                }
              end
            end
          end
        end
      end
    end
  end
end
