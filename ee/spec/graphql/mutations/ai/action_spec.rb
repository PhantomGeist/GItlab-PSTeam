# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Action, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }
  let_it_be(:resource, reload: true) { create(:issue) }
  let(:resource_id) { resource.to_gid.to_s }
  let(:request_id) { 'uuid' }
  let(:request) { instance_double(ActionDispatch::Request, headers: { "Referer" => "foobar" }) }
  let(:context) { { current_user: user, request: request } }
  let(:expected_options) { {} }

  subject(:mutation) { described_class.new(object: nil, context: context, field: nil) }

  describe '#ready?' do
    let(:arguments) do
      { summarize_comments: { resource_id: resource_id }, client_subscription_id: 'id' }
    end

    it { is_expected.to be_ready(**arguments) }

    context 'when no arguments are set' do
      let(:arguments) { {} }

      it 'raises error' do
        expect { subject.ready?(**arguments) }
          .to raise_error(
            Gitlab::Graphql::Errors::ArgumentError,
            described_class::MUTUALLY_EXCLUSIVE_ARGUMENTS_ERROR
          )
      end
    end
  end

  describe '#resolve' do
    subject do
      mutation.resolve(**input)
    end

    shared_examples_for 'an AI action' do
      context 'when resource_id is not for an Ai::Model' do
        let(:resource_id) { "gid://gitlab/Note/#{resource.id}" }

        it 'raises error' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ArgumentError)
        end
      end

      context 'when resource cannot be found' do
        let(:resource_id) { "gid://gitlab/Issue/#{non_existing_record_id}" }

        it 'raises error' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the action is called too many times' do
        it 'raises error' do
          expect(Gitlab::ApplicationRateLimiter).to(
            receive(:throttled?).with(:ai_action, scope: [user]).and_return(true)
          )

          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable, /too many times/)
        end
      end

      context 'when user cannot read resource' do
        it 'raises error' do
          allow(Ability)
            .to receive(:allowed?)
            .with(user, "read_#{resource.to_ability_name}", resource)
            .and_return(false)

          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when user is allowed to read resource' do
        before do
          allow(Ability)
              .to receive(:allowed?)
              .with(user, "read_#{resource.to_ability_name}", resource)
              .and_return(true)
        end

        context 'when the user is not a member' do
          it 'raises error' do
            expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end

        context 'when the resource does not have a parent' do
          let(:resource) { user }

          it 'does not raise an error' do
            expect { subject }.not_to raise_error
          end
        end
      end

      context 'when the user can perform AI action' do
        before do
          resource.project.add_developer(user)
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(openai_experimentation: false)
          end

          it 'raises error' do
            expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end

        it 'calls Llm::ExecuteMethodService' do
          expect_next_instance_of(
            Llm::ExecuteMethodService,
            user,
            resource,
            expected_method,
            expected_options
          ) do |svc|
            expect(svc)
              .to receive(:execute)
              .and_return(ServiceResponse.success(
                payload: {
                  ai_message: build(:ai_message, request_id: request_id)
                }))
          end

          expect(subject[:errors]).to be_empty
          expect(subject[:request_id]).to eq(request_id)
        end

        context 'when resource is null' do
          let(:resource_id) { nil }

          it 'calls Llm::ExecuteMethodService' do
            expect_next_instance_of(
              Llm::ExecuteMethodService,
              user,
              nil,
              expected_method,
              expected_options
            ) do |svc|
              expect(svc)
                .to receive(:execute)
                .and_return(ServiceResponse.success(
                  payload: {
                    ai_message: build(:ai_message, request_id: request_id)
                  }))
            end

            expect(subject[:errors]).to be_empty
            expect(subject[:request_id]).to eq(request_id)
          end
        end

        context 'when Llm::ExecuteMethodService errors out' do
          it 'returns errors' do
            expect_next_instance_of(
              Llm::ExecuteMethodService,
              user,
              resource,
              expected_method,
              expected_options
            ) do |svc|
              expect(svc)
                .to receive(:execute)
                .and_return(ServiceResponse.error(message: 'error'))
            end

            expect(subject[:errors]).to eq(['error'])
            expect(subject[:request_id]).to be_nil
          end
        end
      end
    end

    context 'when chat input is set ' do
      let_it_be(:project) { create(:project, :repository).tap { |p| p.add_developer(user) } }
      let_it_be(:issue) { create(:issue, project: project) }

      let(:input) { { chat: { resource_id: resource_id } } }

      it_behaves_like 'an AI action' do
        let(:expected_method) { :chat }
        let(:expected_options) { { referer_url: "foobar" } }
      end
    end

    context 'when summarize_comments input is set' do
      let(:input) { { summarize_comments: { resource_id: resource_id } } }
      let(:expected_method) { :summarize_comments }
      let(:expected_options) { {} }

      it_behaves_like 'an AI action'
    end

    context 'when client_subscription_id input is set' do
      let(:input) { { summarize_comments: { resource_id: resource_id }, client_subscription_id: 'id' } }
      let(:expected_method) { :summarize_comments }
      let(:expected_options) { { client_subscription_id: 'id' } }

      it_behaves_like 'an AI action'
    end

    context 'when explain_vulnerability input is set' do
      before do
        allow(Ability)
            .to receive(:allowed?)
            .and_call_original

        allow(Ability)
            .to receive(:allowed?)
            .with(user, :explain_vulnerability, user)
            .and_return(true)
      end

      let(:input) { { explain_vulnerability: { resource_id: resource_id, include_source_code: true } } }
      let(:expected_method) { :explain_vulnerability }
      let(:expected_options) { { include_source_code: true } }

      it_behaves_like 'an AI action'
    end
  end
end
