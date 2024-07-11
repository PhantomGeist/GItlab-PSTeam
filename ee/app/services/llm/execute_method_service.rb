# frozen_string_literal: true

module Llm
  class ExecuteMethodService < BaseService
    # This list of methods will expand as we add more methods to support.
    # Could also be abstracted to another class specific to find the appropriate method service.
    METHODS = {
      analyze_ci_job_failure: Llm::AnalyzeCiJobFailureService,
      explain_vulnerability: ::Llm::ExplainVulnerabilityService,
      summarize_comments: Llm::GenerateSummaryService,
      summarize_review: Llm::MergeRequests::SummarizeReviewService,
      explain_code: Llm::ExplainCodeService,
      tanuki_bot: Llm::TanukiBotService,
      generate_test_file: Llm::GenerateTestFileService,
      generate_description: Llm::GenerateDescriptionService,
      generate_commit_message: Llm::GenerateCommitMessageService,
      chat: Llm::ChatService,
      fill_in_merge_request_template: Llm::FillInMergeRequestTemplateService
    }.freeze

    INTERNAL_METHODS = {
      categorize_question: Llm::Internal::CategorizeChatQuestionService
    }.freeze

    def initialize(user, resource, method, options = {})
      super(user, resource, options)

      @method = method
    end

    def execute
      full_methods_list = METHODS.merge(INTERNAL_METHODS)
      return error('Unknown method') unless full_methods_list.key?(method)

      result = full_methods_list[method].new(user, resource, options).execute

      track_snowplow_event(result)

      result
    end

    private

    attr_reader :method

    def track_snowplow_event(result)
      Gitlab::Tracking.event(
        self.class.to_s,
        "execute_llm_method",
        label: method.to_s,
        property: result.success? ? "success" : "error",
        user: user,
        namespace: namespace,
        project: project
      )
    end

    def namespace
      case resource
      when Group
        resource
      when Project
        resource.group
      when User
        nil
      else
        case resource&.resource_parent
        when Group
          resource.resource_parent
        when Project
          resource.resource_parent.group
        end
      end
    end

    def project
      if resource.is_a?(Project)
        resource
      elsif resource.is_a?(Group) || resource.is_a?(User)
        nil
      elsif resource&.resource_parent.is_a?(Project)
        resource.resource_parent
      end
    end
  end
end
