# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::ProgrammingLanguage, feature_category: :code_suggestions do
  describe '.detect_from_filename' do
    subject { described_class.detect_from_filename(file_name)&.name }

    described_class::SUPPORTED_LANGUAGES.each do |lang, exts|
      exts.each do |ext|
        context "for the file extension #{ext}" do
          let(:file_name) { "file.#{ext}" }

          it { is_expected.to eq(lang) }
        end
      end
    end

    context "for an unsupported language" do
      let(:file_name) { "file.nothing" }

      it { is_expected.to eq(described_class::DEFAULT_NAME) }
    end

    context "for no file extension" do
      let(:file_name) { "file" }

      it { is_expected.to eq(described_class::DEFAULT_NAME) }
    end

    context "for no file_name" do
      let(:file_name) { "" }

      it { is_expected.to eq(described_class::DEFAULT_NAME) }
    end
  end

  describe '#single_line_comment_format' do
    subject { language.single_line_comment_format }

    described_class::LANGUAGE_COMMENT_FORMATS.each do |languages, format|
      languages.each do |lang|
        context "for the language #{lang}" do
          let(:language) { described_class.new(lang) }
          let(:expected_format) { format[:single_regexp] || format[:single] }

          it { is_expected.to eq(expected_format) }
        end
      end
    end

    context 'for unknown language' do
      let(:language) { described_class.new('unknown') }

      it { is_expected.to eq(described_class::DEFAULT_FORMAT[:single_regexp]) }
    end

    context 'for an unspecified language' do
      let(:language) { described_class.new('') }

      it { is_expected.to eq(described_class::DEFAULT_FORMAT[:single_regexp]) }
    end

    context 'when single_regexp is specified' do
      let(:language) { described_class.new('VBScript') }

      it 'will prefer regexp to string' do
        is_expected.to be_a(Regexp)
      end
    end
  end

  describe '#single_line_comment?' do
    include_context 'with comment prefixes'

    subject { described_class.new(language).single_line_comment?(content) }

    shared_examples 'single line comment for supported language' do
      context "when it is a comment" do
        let(:content) { "#{prefix} this is a comment " }

        it { is_expected.to be_truthy }
      end

      context "when it is not a comment" do
        let(:content) { "this is not a comment " }

        it { is_expected.to be_falsey }
      end

      context "when line doesn't start with comment" do
        let(:content) { "def something() { #{prefix} this is a comment " }

        it { is_expected.to be_falsey }
      end

      context "when there is whitespace before the comment" do
        let(:content) { "      #{prefix} this is a comment " }

        it { is_expected.to be_truthy }
      end

      context "when it is a comment for different language" do
        let(:non_comment_prefix) { prefix == '#' ? '//' : '#' }
        let(:content) { "#{non_comment_prefix} this is a comment " }

        it { is_expected.to be_falsey }
      end
    end

    languages_with_single_line_comment_prefix.each do |lang, pref|
      context "with language #{lang} and prefix #{pref}" do
        let(:language) { lang }
        let(:prefix) { pref }

        it_behaves_like 'single line comment for supported language'
      end
    end

    languages_missing_single_line_comments.each do |lang|
      context "with language #{lang}" do
        let(:language) { lang }

        context 'with a generic comment' do
          let(:content) { "// this is a comment " }

          it { is_expected.to be_falsey }
        end
      end
    end

    context "when the language is not supported" do
      let(:language) { 'foo' }

      context "when a common comment prefix is used" do
        let(:content) { "// this is a comment " }

        it { is_expected.to be_truthy }
      end

      context "when a special comment prefix is used" do
        let(:content) { "; this is a comment" }

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#examples' do
    context 'when there is no examples defined' do
      let(:language_name) { 'noExamplesLanguage' }

      # GitLab Duo code generation instruction see:
      # https://docs.gitlab.com/ee/user/project/repository/code_suggestions/
      # stub SUPPORTED_LANGUAGES constant on described_class
      # to return { language_name => %w[.noex] }
      before do
        stub_const("#{described_class}::SUPPORTED_LANGUAGES", { language_name => %w[.noex] })
      end

      # GitLab Duo code generation instruction see:
      # https://docs.gitlab.com/ee/user/project/repository/code_suggestions/
      # generate rspec test case for #examples instance method
      # that return empty array
      it 'returns empty array when there are no examples' do
        expect(described_class.new(language_name).examples).to eq([])
      end
    end

    # GitLab Duo code generation instruction see:
    # https://docs.gitlab.com/ee/user/project/repository/code_suggestions/
    # generate context where there is an examples for
    # language defined with language_name
    context 'when there are examples defined' do
      let(:language_name) { 'Ruby' }

      # GitLab Duo code generation instruction see:
      # https://docs.gitlab.com/ee/user/project/repository/code_suggestions/
      # generate one line assertion with expect that examples method
      # return array containing hashes
      # with keys: example and response
      it 'returns array of hashes with example and response' do
        expect(described_class.new(language_name).examples).to all(include('example', 'response'))
      end
    end
  end
end
