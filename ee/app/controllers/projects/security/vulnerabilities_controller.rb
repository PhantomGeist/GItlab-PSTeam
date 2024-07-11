# frozen_string_literal: true

module Projects
  module Security
    class VulnerabilitiesController < Projects::ApplicationController
      include IssuableActions
      include GovernUsageProjectTracking

      before_action do
        push_frontend_feature_flag(:create_vulnerability_jira_issue_via_graphql, @project)
        push_frontend_feature_flag(:openai_experimentation)
        push_frontend_feature_flag(:ai_global_switch, type: :ops)
      end

      before_action :vulnerability, except: [:new]
      before_action :authorize_admin_vulnerability!, except: [:show, :discussions]
      before_action :authorize_read_vulnerability!, except: [:new]

      alias_method :vulnerable, :project

      feature_category :vulnerability_management
      urgency :low
      track_govern_activity 'security_vulnerabilities', :show

      def show
        push_force_frontend_feature_flag(
          :explain_vulnerability,
          can?(current_user, :explain_vulnerability, vulnerability)
        )
        pipeline = vulnerability.finding.first_finding_pipeline
        @pipeline = pipeline if Ability.allowed?(current_user, :read_pipeline, pipeline)
        @gfm_form = true
      end

      private

      def vulnerability
        @issuable = @noteable = @vulnerability ||= vulnerable.vulnerabilities.find(params[:id])
      end

      alias_method :issuable, :vulnerability
      alias_method :noteable, :vulnerability

      def issue_serializer
        IssueSerializer.new(current_user: current_user)
      end
    end
  end
end
