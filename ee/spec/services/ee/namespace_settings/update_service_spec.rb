# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::NamespaceSettings::UpdateService, feature_category: :groups_and_projects do
  let(:group) { create(:group) }
  let(:user) { create(:user) }

  subject { NamespaceSettings::UpdateService.new(user, group, params).execute }

  describe '#execute' do
    context 'as a normal user' do
      let(:params) { { prevent_forking_outside_group: true } }

      it 'does not change settings' do
        subject

        expect { group.save! }
          .not_to(change { group.namespace_settings.prevent_forking_outside_group })
      end

      it 'registers an error' do
        subject

        expect(group.errors[:prevent_forking_outside_group]).to include('Prevent forking setting was not saved')
      end
    end

    context 'as a group owner' do
      before do
        group.add_owner(user)
      end

      context 'for a group that does not have prevent forking feature' do
        let(:params) { { prevent_forking_outside_group: true } }

        it 'does not change settings' do
          subject

          expect { group.save! }
            .not_to(change { group.namespace_settings.prevent_forking_outside_group })
        end

        it 'registers an error' do
          subject

          expect(group.errors[:prevent_forking_outside_group]).to include('Prevent forking setting was not saved')
        end
      end

      context 'for a group that has prevent forking feature' do
        let(:params) { { prevent_forking_outside_group: true } }

        before do
          stub_licensed_features(group_forking_protection: true)
        end

        it 'changes settings' do
          subject
          group.save!

          expect(group.namespace_settings.reload.prevent_forking_outside_group).to eq(true)
        end
      end

      context 'when ai settings change', :saas do
        before do
          allow(Gitlab).to receive(:com?).and_return(true)
          stub_ee_application_setting(should_check_namespace_plan: true)
          stub_licensed_features(ai_features: true)
          allow(group.namespace_settings).to receive(:ai_settings_allowed?).and_return(true)
          group.update!(third_party_ai_features_enabled: false)
        end

        context 'when third_party_ai_features_enabled changes' do
          let(:params) { { third_party_ai_features_enabled: true } }

          it 'publishes an event' do
            expect { subject }.to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
              .with(group_id: group.id)
          end
        end

        context 'when experiment_features_enabled changes' do
          let(:params) { { experiment_features_enabled: true } }

          it 'publishes an event' do
            expect { subject }.to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
              .with(group_id: group.id)
          end
        end

        context 'when third_party_ai_features_enabled and experiment_features_enabled changes' do
          let(:params) { { third_party_ai_features_enabled: true, experiment_features_enabled: true } }

          it 'publishes an event' do
            expect { subject }.to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
              .with(group_id: group.id)
          end
        end

        context 'when AI related setting does not change' do
          let(:params) { { third_party_ai_features_enabled: false } }

          it 'does not publish an event' do
            expect { subject }.not_to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
          end
        end
      end
    end
  end
end
