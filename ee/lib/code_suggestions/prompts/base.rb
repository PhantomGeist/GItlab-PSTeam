# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    class Base
      include Gitlab::Utils::StrongMemoize

      def initialize(params)
        @params = params
      end

      private

      attr_reader :params

      def file_name
        params.dig(:current_file, :file_name).to_s
      end

      def file_path_info
        File.path(file_name)
      end

      def extension
        File.extname(file_name).delete_prefix('.')
      end
      strong_memoize_attr :extension

      def language
        ::CodeSuggestions::ProgrammingLanguage.detect_from_filename(file_name)
      end
      strong_memoize_attr :language

      def prefix
        params.dig(:current_file, :content_above_cursor)
      end

      def suffix
        params.dig(:current_file, :content_below_cursor)
      end
    end
  end
end
