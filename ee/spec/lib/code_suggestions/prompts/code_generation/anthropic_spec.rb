# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeGeneration::Anthropic, feature_category: :code_suggestions do
  let(:prefix) do
    <<~PREFIX
      package main

      import "fmt"

      func main() {
    PREFIX
  end

  let(:instruction) { 'Print a hello world message' }
  let(:file_name) { 'main.go' }

  let(:unsafe_params) do
    {
      'current_file' => {
        'file_name' => file_name,
        'content_above_cursor' => prefix
      },
      'telemetry' => [{ 'model_engine' => 'anthropic' }]
    }
  end

  let(:params) do
    {
      prefix: prefix,
      instruction: instruction,
      current_file: unsafe_params['current_file'].with_indifferent_access
    }
  end

  subject { described_class.new(params) }

  describe '#request_params' do
    context 'when prefix is present' do
      it 'returns expected request params' do
        request_params = {
          model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
          prompt_version: 2,
          prompt: <<~PROMPT


            Human: You are a code completion AI that writes high-quality code like a senior engineer.
            You are looking at 'main.go' file. You write code in between tags as in this example:

            <new_code>
            // Code goes here
            </new_code>

            This is a task to write new Go code in a file 'main.go', based on a given description.
            You get the already existing code file in <existing_code> XML tags.
            You get the description of the code that needs to be created in <instruction> XML tags.

            It is your task to write valid and working Go code.
            Only return in your response new code.
            Do not provide any explanation.

            <existing_code>
            package main

            import "fmt"

            func main() {

            </existing_code>


            <instruction>
              Print a hello world message
            </instruction>


            Assistant: <new_code>
          PROMPT
        }

        expect(subject.request_params).to eq(request_params)
      end
    end

    context 'when prefix is blank' do
      let(:prefix) { '' }

      it 'returns expected request params' do
        request_params = {
          model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
          prompt_version: 2,
          prompt: <<~PROMPT


            Human: You are a code completion AI that writes high-quality code like a senior engineer.
            You are looking at 'main.go' file. You write code in between tags as in this example:

            <new_code>
            // Code goes here
            </new_code>

            This is a task to write new Go code in a file 'main.go', based on a given description.

            You get the description of the code that needs to be created in <instruction> XML tags.

            It is your task to write valid and working Go code.
            Only return in your response new code.
            Do not provide any explanation.



            <instruction>
              Print a hello world message
            </instruction>


            Assistant: <new_code>
          PROMPT
        }

        expect(subject.request_params).to eq(request_params)
      end
    end

    context 'when langauge is unknown' do
      let(:file_name) { 'file_without_extension' }

      it 'returns expected request params' do
        request_params = {
          model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
          prompt_version: 2,
          prompt: <<~PROMPT


            Human: You are a code completion AI that writes high-quality code like a senior engineer.
            You are looking at 'file_without_extension' file. You write code in between tags as in this example:

            <new_code>
            // Code goes here
            </new_code>

            This is a task to write new  code in a file 'file_without_extension', based on a given description.
            You get the already existing code file in <existing_code> XML tags.
            You get the description of the code that needs to be created in <instruction> XML tags.

            It is your task to write valid and working  code.
            Only return in your response new code.
            Do not provide any explanation.

            <existing_code>
            package main

            import "fmt"

            func main() {

            </existing_code>


            <instruction>
              Print a hello world message
            </instruction>


            Assistant: <new_code>
          PROMPT
        }

        expect(subject.request_params).to eq(request_params)
      end
    end

    context 'when language is not supported' do
      let(:file_name) { 'README.md' }

      it 'returns expected request params' do
        request_params = {
          model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
          prompt_version: 2,
          prompt: <<~PROMPT


            Human: You are a code completion AI that writes high-quality code like a senior engineer.
            You are looking at 'README.md' file. You write code in between tags as in this example:

            <new_code>
            // Code goes here
            </new_code>

            This is a task to write new  code in a file 'README.md', based on a given description.
            You get the already existing code file in <existing_code> XML tags.
            You get the description of the code that needs to be created in <instruction> XML tags.

            It is your task to write valid and working  code.
            Only return in your response new code.
            Do not provide any explanation.

            <existing_code>
            package main

            import "fmt"

            func main() {

            </existing_code>


            <instruction>
              Print a hello world message
            </instruction>


            Assistant: <new_code>
          PROMPT
        }

        expect(subject.request_params).to eq(request_params)
      end
    end
  end
end
