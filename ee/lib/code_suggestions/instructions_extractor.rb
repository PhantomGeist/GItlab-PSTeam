# frozen_string_literal: true

module CodeSuggestions
  class InstructionsExtractor
    INTENT_COMPLETION = 'completion'
    INTENT_GENERATION = 'generation'

    # Regex is looking for something that looks like a _single line_ code comment.
    # It looks for GitLab Duo Generate and at least 10 characters
    # afterwards.
    # It is case-insensitive.
    # It searches for the last instance of a match by looking for the end
    # of a text block and an optional line break.
    FIRST_COMMENT_REGEX = "(?<comment>%{comment_format})[ \\t]?%{generate_prefix}[ \\t]*(?<instruction>[^\\r\\n]{10,})\\s*\\Z" # rubocop:disable Layout/LineLength
    ALWAYS_GENERATE_PREFIX = %r{.*?}
    GENERATE_COMMENT_PREFIX = "GitLab Duo Generate:"

    EMPTY_LINES_LIMIT = 1
    MIN_LINES_OF_CODE = 5

    def initialize(language, content, intent, skip_generate_comment_prefix)
      @language = language
      @content = content
      @intent = intent
      @skip_generate_comment_prefix = skip_generate_comment_prefix
    end

    def extract
      return {} if intent == INTENT_COMPLETION

      lines = content.to_s.lines
      prefix, comment_block = prefix_and_comment(lines)
      instruction = get_instruction(lines, comment_block)

      return {} if !instruction && intent != INTENT_GENERATION

      {
        prefix: prefix,
        instruction: instruction
      }
    end

    private

    attr_reader :language, :content, :intent, :skip_generate_comment_prefix

    def prefix_and_comment(lines)
      comment_block = []
      trimmed_lines = 0

      lines.reverse_each do |line|
        next trimmed_lines += 1 if trimmed_lines < EMPTY_LINES_LIMIT && comment_block.empty? && line.strip.empty?
        break unless language.single_line_comment?(line)

        comment_block.unshift(line)
      end

      # lines before the last comment block
      comment_lines_count = comment_block.length + trimmed_lines
      prefix_lines = comment_lines_count > 0 ? lines[0...-comment_lines_count] : lines
      prefix = prefix_lines.join('').chomp

      [prefix, comment_block]
    end

    def get_instruction(lines, comment_block)
      if comment_block.first&.match(first_line_regex)
        instruction = comment_block
        .map { |line| line.gsub(language.single_line_comment_format, '').strip }
        .join("\n")
        .gsub(/GitLab Duo Generate:\s?/, '')

        return instruction if instruction
      end

      # Instead of iterating through all lines, we abort when reach `MIN_LINES_OF_CODE`
      non_comment_lines = lines.lazy.reject do |line|
        line.blank? || language.single_line_comment?(line)
      end.take(MIN_LINES_OF_CODE) # rubocop:disable CodeReuse/ActiveRecord

      return 'Create more new code for this file.' if non_comment_lines.count < MIN_LINES_OF_CODE

      nil
    end

    def first_line_regex
      return ALWAYS_GENERATE_PREFIX if intent == INTENT_GENERATION

      generate_prefix = GENERATE_COMMENT_PREFIX unless skip_generate_comment_prefix
      comment_format = language.single_line_comment_format
      Regexp.new(
        format(FIRST_COMMENT_REGEX, { comment_format: comment_format, generate_prefix: generate_prefix }),
        'im'
      )
    end
  end
end
