# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ServiceAccessToken, type: :model, feature_category: :application_performance do
  describe '.expired', :freeze_time do
    let_it_be(:expired_token) { create(:service_access_token, :expired) }
    let_it_be(:active_token) {  create(:service_access_token, :active) }

    it 'selects all expired tokens' do
      expect(described_class.expired).to match_array([expired_token])
    end
  end

  describe '.active', :freeze_time do
    let_it_be(:expired_token) { create(:service_access_token, :expired) }
    let_it_be(:active_token) {  create(:service_access_token, :active) }

    it 'selects all active tokens' do
      expect(described_class.active).to match_array([active_token])
    end
  end

  describe '#token' do
    let(:token_value) { 'Abc' }

    it 'is encrypted' do
      subject.token = token_value

      aggregate_failures do
        expect(subject.encrypted_token_iv).to be_present
        expect(subject.encrypted_token).to be_present
        expect(subject.encrypted_token).not_to eq(token_value)
        expect(subject.token).to eq(token_value)
      end
    end

    describe 'validations' do
      it { is_expected.to validate_presence_of(:token) }
      it { is_expected.to validate_presence_of(:expires_at) }
    end
  end
end
