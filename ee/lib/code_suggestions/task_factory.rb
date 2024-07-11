# frozen_string_literal: true

module CodeSuggestions
  class TaskFactory
    include Gitlab::Utils::StrongMemoize

    VERTEX_AI = :vertex_ai
    ANTHROPIC = :anthropic

    # We determined this in an experimental way, without any deep measurements.
    # We're going to iterate on this based on how different AI models performing for these languages.
    ANTHROPIC_CODE_COMPLETION_LANGUAGES = %w[Ruby TypeScript].freeze
    ANTHROPIC_CODE_GENERATION_LANGUAGES = %w[Ruby TypeScript].freeze

    def initialize(current_user, params:, unsafe_passthrough_params: {})
      @current_user = current_user
      @params = params
      @unsafe_passthrough_params = unsafe_passthrough_params

      @prefix = params.dig(:current_file, :content_above_cursor)
      @intent = params[:intent]
    end

    def task
      instructions = CodeSuggestions::InstructionsExtractor
        .new(language, prefix, intent, skip_generate_comment_prefix?).extract

      if instructions.empty?
        return CodeSuggestions::Tasks::CodeCompletion.new(
          params: code_completion_params,
          unsafe_passthrough_params: unsafe_passthrough_params
        )
      end

      CodeSuggestions::Tasks::CodeGeneration.new(
        params: code_generation_params(instructions),
        unsafe_passthrough_params: unsafe_passthrough_params
      )
    end

    private

    attr_reader :current_user, :params, :unsafe_passthrough_params, :prefix, :intent

    def language
      CodeSuggestions::ProgrammingLanguage.detect_from_filename(params.dig(:current_file, :file_name))
    end
    strong_memoize_attr(:language)

    # TODO: Remove `skip_generate_comment_prefix` when `code_suggestions_no_comment_prefix` feature flag
    # is removed https://gitlab.com/gitlab-org/gitlab/-/issues/424879
    def skip_generate_comment_prefix?
      Feature.enabled?(:code_generation_no_comment_prefix, current_user)
    end
    strong_memoize_attr(:skip_generate_comment_prefix?)

    def code_completion_model_family
      if code_completion_split_by_language?
        return ANTHROPIC_CODE_COMPLETION_LANGUAGES.include?(language&.name) ? ANTHROPIC : VERTEX_AI
      end

      Feature.enabled?(:code_completion_anthropic, current_user) ? ANTHROPIC : VERTEX_AI
    end

    def code_generation_model_family
      if code_generation_split_by_language?
        return ANTHROPIC_CODE_GENERATION_LANGUAGES.include?(language&.name) ? ANTHROPIC : VERTEX_AI
      end

      Feature.enabled?(:code_generation_anthropic, current_user) ? ANTHROPIC : VERTEX_AI
    end

    def code_completion_split_by_language?
      Feature.enabled?(:code_completion_split_by_language, current_user)
    end
    strong_memoize_attr(:code_completion_split_by_language?)

    def code_generation_split_by_language?
      Feature.enabled?(:code_generation_split_by_language, current_user)
    end
    strong_memoize_attr(:code_generation_split_by_language?)

    def code_completion_params
      params.merge(code_completion_model_family: code_completion_model_family)
    end

    def code_generation_params(instructions)
      params.merge(
        prefix: instructions[:prefix],
        instruction: instructions[:instruction],
        code_generation_model_family: code_generation_model_family
      )
    end
  end
end
