# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::Completions::AnalyzeCiJobFailure, feature_category: :continuous_integration do
  let(:options) { {} }

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:job) { create(:ci_build, :trace_live) }

  let(:ai_response) { { 'predictions' => [{ 'content' => 'world' }] } }

  let(:prompt_message) do
    build(:ai_message, :analyze_ci_job_failure, user: user, resource: job, request_id: 'uuid')
  end

  subject { described_class.new(prompt_message, nil, options) }

  describe '#execute' do
    it 'stores the ai request result' do
      expect_next_instance_of(Gitlab::Llm::VertexAi::Client) do |client|
        expect(client).to receive(:text).with(
          hash_including(content: kind_of(String))
        ) do |prompt|
          expect(prompt[:content]).to include('You are an ai assistant explaining the root cause of a CI')
          expect(prompt[:content]).to include(job.trace.raw)
        end.and_return(ai_response)
      end

      subject.execute

      saved_content = Ai::JobFailureAnalysis.new(job).content

      expect(saved_content).to eq 'world'
    end
  end
end
