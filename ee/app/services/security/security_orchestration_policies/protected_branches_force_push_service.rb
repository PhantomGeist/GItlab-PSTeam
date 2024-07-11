# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class ProtectedBranchesForcePushService < BaseProjectService
      def execute
        return [] unless ::Feature.enabled?(:scan_result_policies_block_force_push, project)

        applicable_branches
      end

      private

      def applicable_branches
        @applicable_branches ||= PolicyBranchesService.new(project: project).scan_result_branches(rules)
      end

      def rules
        project.all_security_orchestration_policy_configurations.flat_map do |config|
          blocking_policies = config.active_scan_result_policies.select do |rule|
            rule.dig(:approval_settings, :prevent_force_pushing)
          end

          blocking_policies.pluck(:rules).flatten # rubocop: disable CodeReuse/ActiveRecord
        end
      end
    end
  end
end
