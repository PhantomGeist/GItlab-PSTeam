# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module CiEditorAssistant
          module Prompts
            class VertexAi
              def self.prompt(options)
                prompt = Utils::Prompt.no_role_text(
                  ::Gitlab::Llm::Chain::Tools::CiEditorAssistant::Executor::PROMPT_TEMPLATE, options
                )

                {
                  prompt: prompt,
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
