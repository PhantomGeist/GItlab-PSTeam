# frozen_string_literal: true

RSpec.shared_context 'with comment prefixes' do
  # Builds a hash with items: { [array of programming languages] => [array of comment prefixes] }
  # for example:
  # {
  #   ["Clojure", "Lisp", "Scheme"]=>[";"],
  #   ["SQL", "Haskell", "Lean"]=>["--"],
  #   ["VBScript"]=>["'", "REM"],
  #   ...
  # }
  # The reason is that LANGUAGE_COMMENT_FORMATS defines either simple string comment prefixes or
  # regexps which match multiple prefix options. If simple string is used, we can just reuse it,
  # if regexp is used, we need to add all matching options here.
  def self.single_line_comment_prefixes
    CodeSuggestions::ProgrammingLanguage::LANGUAGE_COMMENT_FORMATS
      .transform_values { |format| Array.wrap(format[:single]) if format[:single] }
      .compact
      .merge({
        %w[VBScript] => ["'", 'REM']
      })
  end

  def self.languages_missing_single_line_comments
    %w[OCaml]
  end

  def self.languages_with_single_line_comment_prefix
    all_prefixes = single_line_comment_prefixes

    CodeSuggestions::ProgrammingLanguage::SUPPORTED_LANGUAGES.keys.each_with_object([]) do |lang, tuples|
      next if languages_missing_single_line_comments.include?(lang)

      prefixes = all_prefixes.find { |langs, _| langs.include?(lang) }&.last
      if prefixes.blank?
        raise "#{lang} has missing single line comment prefix, if it's a simple string match, add it to " \
              "LANGUAGE_COMMENT_FORMATS, if it's a regexp, add all regexp possibilities to " \
              "single_line_comment_prefixes"
      end

      prefixes.each { |prefix| tuples << [lang, prefix] }
    end
  end
end
