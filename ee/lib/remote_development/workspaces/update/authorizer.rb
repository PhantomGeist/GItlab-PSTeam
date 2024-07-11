# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Update
      class Authorizer
        include Messages

        # @param [Hash] value
        # @return [Result]
        def self.authorize(value)
          value => { workspace: RemoteDevelopment::Workspace => workspace, current_user: User => current_user }

          if current_user.can?(:update_workspace, workspace)
            Result.ok(value)
          else
            Result.err(Unauthorized.new)
          end
        end
      end
    end
  end
end
