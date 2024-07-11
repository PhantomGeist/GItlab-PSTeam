# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      class Anthropic < CodeSuggestions::Prompts::Base
        GATEWAY_PROMPT_VERSION = 2

        def request_params
          {
            model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
            prompt: prompt,
            prompt_version: GATEWAY_PROMPT_VERSION
          }
        end

        private

        def prompt
          <<~PROMPT
            Human: We want to fill in new #{language.name} code inside the file '#{file_path_info}'.
            The existing code is provided in <existing_code></existing_code> tags.
            The new code belongs at the cursor, which is currently at the position of the <cursor> tag.
            Review the existing code to understand it's logic and format then try to determine the most likely new code at the cursor.
            Review the new code step by step to ensure the following
            1. When inserted at the cursor it is valid #{language.name} code.
            2. It matches the existing code's variable, parameter and function names.
            3. It does not repeat any existing code, if code has been repeated, discard it and try again.
            Return new code enclosed in <new_code></new_code> tags which can be inserted at the <cursor> tag.
            If you are not able to write code based on the given instructions return an empty result like <new_code></new_code>.

            #{examples_section}

            <existing_code>
              #{prefix}<cursor>#{suffix}
            </existing_code>

            Assistant: #{prefix&.lines&.last}<new_code>
          PROMPT
        end

        def examples_section
          examples_template = <<~EXAMPLES
          You got example scenarios between <examples> XML tag.

          <examples>
          <% examples_array.each do |use_case| %>
            <example>
              H: <existing_code>
                   <%= use_case['example'] %>
                 </existing_code>

              A: <%= use_case['response'] %></new_code>
            </example>
          <% end %>
          </examples>
          EXAMPLES

          examples_array = language.examples
          return if examples_array.empty?

          ERB.new(examples_template).result(binding)
        end
      end
    end
  end
end
