# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::MergeRequests::SummarizeDiffService, feature_category: :code_review_workflow do
  let_it_be(:user)          { create(:user) }
  let_it_be(:project)       { create(:project, :with_namespace_settings, :repository, :public) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let_it_be(:merge_request_2) { create(:merge_request) }
  let_it_be(:project_2)       { merge_request_2.project }

  let_it_be(:example_answer) { "This merge request includes changes to limit the transfer..." }
  let_it_be(:example_response) do
    {
      "predictions" => [
        {
          "candidates" => [
            {
              "author" => "",
              "content" => example_answer
            }
          ],
          "safetyAttributes" => {
            "categories" => ["Violent"],
            "scores" => [0.4000000059604645],
            "blocked" => false
          }
        }
      ],
      "deployedModelId" => "1",
      "model" => "projects/1/locations/us-central1/models/text-bison",
      "modelDisplayName" => "text-bison",
      "modelVersionId" => "1"
    }
  end

  let(:tracking_context) { { action: 'summarize_diff' } }
  let(:response_double) { example_response.to_json }
  let(:errored_response_double) { { error: "true" }.to_json }

  subject(:service) do
    described_class.new(title: merge_request.title, user: user, diff:
                                          merge_request.merge_request_diff)
  end

  describe "#execute" do
    before do
      project.add_developer(user)
      stub_licensed_features(summarize_mr_changes: true)

      merge_request.project.namespace.namespace_settings.update_attribute(:experiment_features_enabled, true)
      merge_request.project.namespace.namespace_settings.update_attribute(:third_party_ai_features_enabled, true)
    end

    context "when the user does not have read access to the MR" do
      it "returns without attempting to summarize" do
        secondary_service = described_class.new(title: merge_request_2.title, user: user, diff:
                                          merge_request_2.merge_request_diff)

        expect(secondary_service).not_to receive(:llm_client)
        expect(secondary_service.execute).to be_nil
      end
    end

    context "when the feature is not enabled" do
      context 'when the openai_experimentation flag is false' do
        before do
          stub_feature_flags(openai_experimentation: false)
        end

        it "returns without attempting to summarize" do
          expect(service).not_to receive(:llm_client)

          service.execute
        end
      end

      context 'when summarize_mr_change feature not avaliable' do
        before do
          stub_licensed_features(summarize_mr_changes: false)
        end

        it "returns without attempting to summarize" do
          expect(service).not_to receive(:llm_client)

          service.execute
        end
      end

      context 'when the project experiment_features_allowed is false' do
        before do
          merge_request.project.namespace.namespace_settings.update_attribute(:experiment_features_enabled, false)
        end

        it "returns without attempting to summarize" do
          expect(service).not_to receive(:llm_client)

          service.execute
        end
      end

      context 'when the project third_party_ai_features_enabled is false' do
        before do
          merge_request.project.namespace.namespace_settings.update_attribute(:third_party_ai_features_enabled, false)
        end

        it "returns without attempting to summarize" do
          expect(service).not_to receive(:llm_client)

          service.execute
        end
      end
    end

    context "when Gitlab::Llm::VertexAi::Client.text returns a typical response" do
      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client, user, tracking_context: tracking_context) do |llm_client|
          allow(llm_client).to receive(:text).and_return(response_double)
        end
      end

      it "returns the content field from the VertexAI response" do
        expect(service.execute).to eq(example_answer)
      end
    end

    context "when Gitlab::Llm::VertexAi::Client.text returns an unsuccessful response" do
      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client, user, tracking_context: tracking_context) do |llm_client|
          allow(llm_client).to receive(:text).and_return(errored_response_double)
        end
      end

      it "returns nil" do
        expect(service.execute).to be_nil
      end
    end

    context "when Gitlab::Llm::VertexAi::Client.text returns an nil response" do
      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client, user, tracking_context: tracking_context) do |llm_client|
          allow(llm_client).to receive(:text).and_return(nil)
        end
      end

      it "returns nil" do
        expect(service.execute).to be_nil
      end
    end

    context "when Gitlab::Llm::VertexAi::Client.text returns a response without parsed_response" do
      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client, user, tracking_context: tracking_context) do |llm_client|
          allow(llm_client).to receive(:text).and_return({ message: "Foo" }.to_json)
        end
      end

      it "returns nil" do
        expect(service.execute).to be_nil
      end
    end
  end
end
