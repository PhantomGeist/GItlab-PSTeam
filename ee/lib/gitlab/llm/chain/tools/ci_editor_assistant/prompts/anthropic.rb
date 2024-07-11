# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module CiEditorAssistant
          module Prompts
            class Anthropic
              def self.prompt(options)
                base_prompt = Utils::Prompt.no_role_text(
                  ::Gitlab::Llm::Chain::Tools::CiEditorAssistant::Executor::PROMPT_TEMPLATE, options
                )
                {
                  prompt: "\n\nHuman: #{base_prompt}\n\nAssistant:```yaml",
                  options: {}
                }
              end
            end
          end
        end
      end
    end
  end
end
