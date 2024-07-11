# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitlab::Llm::VertexAi::TokenLoader, feature_category: :ai_abstraction_layer do
  let(:current_access_token) { SecureRandom.uuid }
  let(:new_access_token) { "x.#{SecureRandom.uuid}.z" }
  let(:private_key) { OpenSSL::PKey::RSA.new(4096) }
  let(:credentials) do
    {
      type: "service_account",
      project_id: SecureRandom.uuid,
      private_key_id: SecureRandom.hex(20),
      private_key: private_key.to_pem,
      client_email: "vertex-ai@#{SecureRandom.hex(4)}.iam.gserviceaccount.com",
      client_id: "1",
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/vertex-ai.iam.gserviceaccount.com"
    }
  end

  before do
    Gitlab::CurrentSettings.update!(vertex_ai_access_token: current_access_token)
    stub_ee_application_setting(vertex_ai_credentials: credentials.to_json)

    stub_request(:post, "https://www.googleapis.com/oauth2/v4/token").to_return(
      status: 200,
      headers: { 'content-type' => 'application/json; charset=utf-8' },
      body: {
        access_token: new_access_token,
        expires_in: 3600,
        scope: "https://www.googleapis.com/auth/cloud-platform",
        token_type: "Bearer"
      }.to_json
    ).times(1)
  end

  describe '#refresh_token!', :use_clean_rails_redis_caching do
    it 'generates a new token and stores it in the database' do
      described_class.new.refresh_token!

      expect(::Gitlab::CurrentSettings.vertex_ai_access_token).to eq(
        new_access_token
      )
    end

    it 'refreshes the rails cache to indicate that the token was refreshed' do
      described_class.new.refresh_token!

      expect(Rails.cache.read('vertex_ai_access_token_expiry')).to eq true
    end
  end

  describe '#current_token', :use_clean_rails_redis_caching do
    context 'when rails cache indicates that the token is expired' do
      it 'generates a new token and stores it in the database' do
        described_class.new.current_token

        expect(::Gitlab::CurrentSettings.vertex_ai_access_token).to eq new_access_token
      end

      it 'updates the cache' do
        expect(Rails.cache.read('vertex_ai_access_token_expiry')).to be_nil

        described_class.new.current_token

        expect(Rails.cache.read('vertex_ai_access_token_expiry')).to eq true
      end

      context 'when there is no token in the database' do
        before do
          Gitlab::CurrentSettings.update!(vertex_ai_access_token: nil)
        end

        it 'generates a new token and stores it in the database and updates the cache' do
          described_class.new.current_token

          expect(::Gitlab::CurrentSettings.vertex_ai_access_token).to eq new_access_token
        end

        it 'updates the cache' do
          described_class.new.current_token

          expect(Rails.cache.read('vertex_ai_access_token_expiry')).to eq true
        end
      end
    end

    context 'when rails cache indicates that token is not expired' do
      it 'uses the existing token' do
        Rails.cache.write('vertex_ai_access_token_expiry', true, expires_in: 10)

        described_class.new.current_token

        expect(::Gitlab::CurrentSettings.vertex_ai_access_token).to eq(
          current_access_token
        )
      end
    end
  end
end
