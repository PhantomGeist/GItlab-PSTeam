# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::InstructionsExtractor, feature_category: :code_suggestions do
  describe '.extract' do
    let(:language) do
      CodeSuggestions::ProgrammingLanguage.new(CodeSuggestions::ProgrammingLanguage::DEFAULT_NAME)
    end

    let(:default_instruction) { 'Create more new code for this file.' }
    let(:intent) { nil }
    let(:skip_generate_comment_prefix) { true }

    subject { described_class.new(language, content, intent, skip_generate_comment_prefix).extract }

    context 'when content is nil' do
      let(:content) { nil }

      it 'sets create instruction' do
        is_expected.to eq({
          prefix: "",
          instruction: default_instruction
        })
      end
    end

    context 'when language is not supported' do
      let(:language) { CodeSuggestions::ProgrammingLanguage.new('foo') }
      let(:content) do
        <<~CODE
          full_name()
          address()
          street()
          city()
          state()
          pincode()

          #{comment_sign}Generate me a function
          #{comment_sign}with 2 arguments
        CODE
      end

      context 'when content uses generic prefix sign' do
        let(:comment_sign) { '#' }

        it 'finds instruction' do
          is_expected.to eq({
            instruction: "Generate me a function\nwith 2 arguments",
            prefix: "full_name()\naddress()\nstreet()\ncity()\nstate()\npincode()\n"
          })
        end
      end

      context 'when content uses special prefix sign' do
        let(:comment_sign) { '!' }

        it 'does not find instruction' do
          is_expected.to eq({})
        end
      end
    end

    context 'when there is instruction' do
      let(:content) do
        <<~CODE
          # Generate me a function
        CODE
      end

      it 'finds instruction' do
        is_expected.to eq({
          instruction: "Generate me a function",
          prefix: ''
        })
      end

      context 'when intent is completion' do
        let(:intent) { 'completion' }

        it 'ignores the instruction' do
          is_expected.to be_empty
        end
      end
    end

    context 'when there is not instruction' do
      let(:content) do
        <<~CODE
          full_name()
          address()
          street()
          city()
          state()
          pincode()
        CODE
      end

      it { is_expected.to be_empty }

      context 'when intent is generation' do
        let(:intent) { 'generation' }

        it 'returns prefix and nil instruction' do
          is_expected.to eq({
            instruction: nil,
            prefix: "full_name()\naddress()\nstreet()\ncity()\nstate()\npincode()"
          })
        end
      end
    end

    shared_examples_for 'detects comments correctly' do
      context 'when there is only one comment line' do
        let(:content) do
          <<~CODE
            #{comment_sign}Generate me a function
          CODE
        end

        specify do
          is_expected.to eq(
            prefix: '',
            instruction: "Generate me a function"
          )
        end
      end

      context 'when the comment is too short' do
        let(:content) do
          <<~CODE
            #{comment_sign}Generate
          CODE
        end

        it 'sets create instruction' do
          is_expected.to eq({
            prefix: '',
            instruction: default_instruction
          })
        end
      end

      context 'when the last line is not a comment but code is less than 5 lines' do
        let(:content) do
          <<~CODE
            #{comment_sign}A function that outputs the first 20 fibonacci numbers

            def fibonacci(x)

          CODE
        end

        it 'finds the instruction' do
          is_expected.to eq({
            prefix: "#{comment_sign}A function that outputs the first 20 fibonacci numbers\n\ndef fibonacci(x)",
            instruction: default_instruction
          })
        end
      end

      context 'when there are some lines above the comment' do
        let(:content) do
          <<~CODE
            full_name()
            address()

            #{comment_sign}Generate me a function
          CODE
        end

        specify do
          is_expected.to eq(
            prefix: "full_name()\naddress()\n",
            instruction: "Generate me a function"
          )
        end
      end

      context 'when there are several comment in a row' do
        let(:content) do
          <<~CODE
            full_name()
            address()

            #{comment_sign}Generate me a function
            #{comment_sign}with 2 arguments
            #{comment_sign}first and last
          CODE
        end

        specify do
          is_expected.to eq(
            prefix: "full_name()\naddress()\n",
            instruction: "Generate me a function\nwith 2 arguments\nfirst and last"
          )
        end
      end

      context 'when there are several comments in a row followed by empty line' do
        let(:content) do
          # rubocop:disable Layout/TrailingWhitespace
          <<~CODE
            full_name()
            address()

            #{comment_sign}Generate me a function
            #{comment_sign}with 2 arguments
            #{comment_sign}first and last\n
          CODE
          # rubocop:enable Layout/TrailingWhitespace
        end

        specify do
          is_expected.to eq(
            prefix: "full_name()\naddress()\n",
            instruction: "Generate me a function\nwith 2 arguments\nfirst and last"
          )
        end
      end

      context 'when there are several comments in a row followed by empty lines' do
        let(:content) do
          <<~CODE
            full_name()
            address()
            street()
            city()
            state()
            pincode()

            #{comment_sign}Generate me a function
            #{comment_sign}with 2 arguments
            #{comment_sign}first and last


          CODE
        end

        it { is_expected.to be_empty }
      end

      context 'when there are several comments in a row followed by other code' do
        let(:content) do
          <<~CODE
            full_name()
            address()
            street()
            city()
            state()
            pincode()

            #{comment_sign}Generate me a function
            #{comment_sign}with 2 arguments
            #{comment_sign}first and last
            other_code()
          CODE
        end

        it { is_expected.to be_empty }
      end

      context 'when there is another multiline comment above' do
        let(:content) do
          <<~CODE
            full_name()
            address()

            #{comment_sign}just some comment
            #{comment_sign}explaining something
            another_function()

            #{comment_sign}Generate me a function
            #{comment_sign}with 2 arguments
            #{comment_sign}first and last
          CODE
        end

        specify do
          expected_prefix = <<~CODE
            full_name()
            address()

            #{comment_sign}just some comment
            #{comment_sign}explaining something
            another_function()
          CODE

          is_expected.to eq(
            prefix: expected_prefix,
            instruction: "Generate me a function\nwith 2 arguments\nfirst and last"
          )
        end
      end

      context 'when the first line of multiline comment does not meet requirements' do
        let(:content) do
          <<~CODE
            full_name()
            address()

            #{comment_sign}just some comment
            #{comment_sign}explaining something
            another_function()

            #{comment_sign}Generate
            #{comment_sign}me a function
            #{comment_sign}with 2 arguments
            #{comment_sign}first and last
          CODE
        end

        let(:expected_prefix) do
          <<~CODE
            full_name()
            address()

            #{comment_sign}just some comment
            #{comment_sign}explaining something
            another_function()
          CODE
        end

        it "sets the create instruction" do
          is_expected.to eq({
            prefix: expected_prefix,
            instruction: default_instruction
          })
        end
      end

      context 'when there is content between comment lines' do
        let(:content) do
          <<~CODE
            full_name()
            address()
            street()
            city()
            state()
            pincode()


            #{comment_sign}just some comment
            #{comment_sign}explaining something

            #{comment_sign}Generate
          CODE
        end

        it "does not find instruction" do
          is_expected.to eq({})
        end
      end

      context "with GitLab Duo Generate prefix" do
        let(:skip_generate_comment_prefix) { false }

        context 'when no prefix in the first line of the comment' do
          let(:content) do
            <<~CODE
              full_name()
              address()

              #{comment_sign}Generate me a function
              #{comment_sign}with 2 arguments
              #{comment_sign}first and last
            CODE
          end

          it 'finds the instruction' do
            is_expected.to eq({
              prefix: "full_name()\naddress()\n",
              instruction: default_instruction
            })
          end
        end

        context 'when there is a prefix in the first line of the comment' do
          let(:content) do
            <<~CODE
              full_name()
              address()

              #{comment_sign}GitLab Duo Generate: Generate me a function
              #{comment_sign}with 2 arguments
              #{comment_sign}first and last
            CODE
          end

          specify do
            is_expected.to eq(
              prefix: "full_name()\naddress()\n",
              instruction: "Generate me a function\nwith 2 arguments\nfirst and last"
            )
          end
        end

        context 'when comments are indented' do
          let(:content) do
            <<~CODE
              full_name()
              address()

                #{comment_sign}GitLab Duo Generate: Generate me a function
                #{comment_sign}with 2 arguments
                #{comment_sign}first and last
            CODE
          end

          specify do
            is_expected.to eq(
              prefix: "full_name()\naddress()\n",
              instruction: "Generate me a function\nwith 2 arguments\nfirst and last"
            )
          end
        end
      end
    end

    context 'when content is a supported language' do
      include_context 'with comment prefixes'

      languages_with_single_line_comment_prefix.each do |lang, pref|
        context "when using language #{lang} and prefix #{pref}" do
          let(:language) { CodeSuggestions::ProgrammingLanguage.new(lang) }
          let(:comment_sign) { pref }

          it_behaves_like 'detects comments correctly'
        end
      end
    end
  end
end
