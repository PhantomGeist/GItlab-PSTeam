# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VerifyPagesDomainService, feature_category: :pages do
  subject(:service) { described_class.new(domain) }

  describe '#execute' do
    context 'when successful verification' do
      shared_examples 'schedules Groups::EnterpriseUsers::BulkAssociateByDomainWorker' do
        it 'schedules Groups::EnterpriseUsers::BulkAssociateByDomainWorker', :aggregate_failures do
          expect(Groups::EnterpriseUsers::BulkAssociateByDomainWorker).to receive(:perform_async).with(domain.id)

          expect(service.execute).to eq(status: :success)
          expect(domain).to be_verified
        end
      end

      context 'when domain is disabled(or new)' do
        let(:domain) { create(:pages_domain, :disabled) }

        before do
          stub_resolver(domain.domain => ['something else', domain.verification_code])
        end

        include_examples 'schedules Groups::EnterpriseUsers::BulkAssociateByDomainWorker'
      end

      context 'when domain is verified' do
        let(:domain) { create(:pages_domain) }

        before do
          stub_resolver(domain.domain => ['something else', domain.verification_code])
        end

        include_examples 'schedules Groups::EnterpriseUsers::BulkAssociateByDomainWorker'
      end
    end

    context 'when unsuccessful verification' do
      shared_examples 'does not schedule Groups::EnterpriseUsers::BulkAssociateByDomainWorker' do
        it 'does not schedule Groups::EnterpriseUsers::BulkAssociateByDomainWorker', :aggregate_failures do
          expect(Groups::EnterpriseUsers::BulkAssociateByDomainWorker).not_to receive(:perform_async)

          expect(service.execute).to eq({ status: :error, message: "Couldn't verify #{domain.domain}" })
          expect(domain).not_to be_verified
        end
      end

      context 'when domain is disabled(or new)' do
        let(:domain) { create(:pages_domain, :disabled) }

        include_examples 'does not schedule Groups::EnterpriseUsers::BulkAssociateByDomainWorker'
      end

      context 'when domain is verified' do
        let(:domain) { create(:pages_domain) }

        include_examples 'does not schedule Groups::EnterpriseUsers::BulkAssociateByDomainWorker'
      end
    end
  end
end
