# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::CreateCompanyLeadService, feature_category: :billing_and_payments do
  let(:user) { build(:user, last_name: 'Jones') }

  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    let(:trial_registration) { true }
    let(:base_params) do
      {
        uid: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        work_email: user.email,
        setup_for_company: user.setup_for_company,
        preferred_language: 'English',
        provider: 'gitlab',
        skip_email_confirmation: true,
        gitlab_com_trial: true,
        jtbd: '_jtbd_',
        comment: '_comment_'
      }
    end

    shared_examples 'correct client attributes' do
      let(:params) do
        base_params.merge(jtbd: nil, trial_onboarding_flow: true)
      end

      let(:service_params) do
        params.merge({ trial: trial_registration, glm_source: 'some_source', glm_content: 'some_content' })
      end

      before do
        subscription_portal_url = ::Gitlab::Routing.url_helpers.subscription_portal_url

        stub_request(:post, "#{subscription_portal_url}/trials#{path}")
        stub_saas_features(onboarding: true)
      end

      it do
        expect(Gitlab::SubscriptionPortal::Client)
          .to receive(:generate_trial)
          .with(params.merge(client_params))
          .and_call_original

        described_class.new(user: user, params: service_params).execute
      end
    end

    context 'when creating an automatic trial' do
      let(:path) { '' }
      let(:trial_registration) { false }

      it_behaves_like 'correct client attributes' do
        let(:client_params) do
          {
            product_interaction: 'SaaS Trial - defaulted',
            glm_source: 'some_source',
            glm_content: 'some_content'
          }
        end
      end
    end

    context 'when creating a trial' do
      let(:path) { '' }

      it_behaves_like 'correct client attributes' do
        let(:client_params) do
          {
            product_interaction: 'SaaS Trial',
            glm_source: 'some_source',
            glm_content: 'some_content'
          }
        end
      end
    end

    it 'successfully creates a trial' do
      allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_trial)
        .with(base_params.merge(product_interaction: 'SaaS Trial - defaulted', trial_onboarding_flow: true))
        .and_return({ success: true })

      result = described_class.new(user: user, params: {
        first_name: user.first_name,
        last_name: user.last_name,
        trial_onboarding_flow: true,
        jobs_to_be_done_other: '_comment_',
        registration_objective: '_jtbd_'
      }).execute

      expect(result.success?).to be true
    end

    context 'when creating trial fails without an error message from the client' do
      it 'error while creating trial' do
        allow(Gitlab::SubscriptionPortal::Client).to receive(:generate_trial).and_return({ success: false })

        result = described_class.new(user: user, params: { trial_onboarding_flow: true }).execute

        expect(result.success?).to be false
        expect(result.reason).to eq(:submission_failed)
        expect(result.errors).to match(['Submission failed'])
      end
    end

    context 'when creating trial fails with an error message from the client' do
      it 'error while creating trial' do
        message = "Last name can't be blank"
        response = Net::HTTPUnprocessableEntity.new(1.0, '422', 'Error')
        gitlab_http_response = instance_double(
          HTTParty::Response,
          code: response.code,
          parsed_response: { errors: message }.stringify_keys,
          response: response,
          body: {}
        )
        # going deeper than usual here to verify the API doesn't change and break this area that relies on
        # symbols for `error`
        allow(Gitlab::HTTP).to receive(:post).and_return(gitlab_http_response)

        result = described_class.new(user: user, params: { trial_onboarding_flow: true }).execute

        expect(result.success?).to be false
        expect(result.reason).to eq(:submission_failed)
        expect(result.errors).to match([message])
      end
    end
  end
end
