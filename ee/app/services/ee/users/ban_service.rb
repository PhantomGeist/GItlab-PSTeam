# frozen_string_literal: true

module EE
  module Users
    module BanService
      extend ::Gitlab::Utils::Override
      include ManagementBaseService

      private

      def event_name
        'ban_user'
      end

      def event_message
        'Banned user'
      end
    end
  end
end
