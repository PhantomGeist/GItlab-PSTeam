# frozen_string_literal: true

module Gitlab
  module Llm
    module Templates
      class CategorizeQuestion
        include Gitlab::Utils::StrongMemoize

        def initialize(user, params = {})
          @user = user
          @params = params
        end

        def to_prompt
          prompt = <<-PROMPT
            \n\nHuman: You are helpful assistant, ready to give as accurate answer as possible in JSON format.

            Given categories below (formatted with XML) return category and detailed_category of question below. Question is prefixed by "q".

            Categories XML:
            %<categories>s

            q: %<question>s

            Return category and detailed category, always using JSON format. Example of said JSON:
            "{"category": "Write, improve, or explain code", "detailed_category": "What are the potential security risks in this code?" }".

            Always return only JSON structure.

            Assistant:
            JSON:
          PROMPT

          format(prompt, question: params[:question], categories: categories_parsed_file)
        end

        private

        attr_reader :user, :params

        def categories_parsed_file
          File.read(File.join(File.dirname(__FILE__), '..', 'fixtures', 'categories.xml'))
        end
      end
    end
  end
end
