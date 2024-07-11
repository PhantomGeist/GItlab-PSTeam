# frozen_string_literal: true

module QA
  RSpec.describe 'Govern', product_group: :compliance do
    shared_examples 'audit event' do |expected_events|
      it 'logs audit events for UI operations' do
        Page::Group::Menu.perform(&:go_to_audit_events)
        expected_events.each do |expected_event|
          expect(page).to have_text(expected_event)
        end
      end
    end

    describe 'Group' do
      let(:group) { create(:group, path: "test-group-#{SecureRandom.hex(8)}") }

      context 'for disable and Enable LFS', :reliable,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347919' do
        before do
          sign_in
          group.visit!
          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform(&:set_lfs_disabled)

          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform(&:set_lfs_enabled)
        end

        it_behaves_like 'audit event', [
          "Changed lfs enabled from false to true",
          /Changed lfs enabled( from true)? to false/
        ]
      end

      context 'for enable and disable membership lock', :reliable,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347900' do
        before do
          sign_in
          group.visit!
          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform(&:set_membership_lock_enabled)

          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform(&:set_membership_lock_disabled)
        end

        it_behaves_like 'audit event', [
          "Changed membership lock from true to false",
          "Changed membership lock from false to true"
        ]
      end

      context 'for enable and disable allow user request access', :reliable,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347902' do
        before do
          sign_in
          group.visit!
          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform(&:toggle_request_access)

          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform(&:toggle_request_access)
        end

        it_behaves_like 'audit event', [
          "Changed request access enabled from true to false",
          "Changed request access enabled from false to true"
        ]
      end

      context 'for enable and disable 2FA requirement', :requires_admin, :reliable, :skip_live_env,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347920' do
        let!(:owner_user) { create(:user) }

        let!(:owner_api_client) do
          Runtime::API::Client.new(:gitlab, user: owner_user, is_new_session: false)
        end

        let(:sandbox_group) do
          Resource::Sandbox.fabricate! do |sandbox_group|
            sandbox_group.path = "gitlab-qa-2fa-recovery-sandbox-group-#{SecureRandom.hex(4)}"
            sandbox_group.api_client = owner_api_client
          end
        end

        let(:two_fa_group) { create(:group, sandbox: sandbox_group, api_client: owner_api_client) }

        before do
          sign_in(as: owner_user)
          two_fa_group.visit!
          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform(&:set_require_2fa_enabled)
          Page::Profile::TwoFactorAuth.perform(&:click_configure_it_later_button)

          two_fa_group.visit!
          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform(&:set_require_2fa_disabled)
        end

        it_behaves_like 'audit event', [
          "Changed require two factor authentication from true to false",
          "Changed require two factor authentication from false to true"
        ]
      end

      context 'for change project creation level', :reliable,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347901' do
        before do
          sign_in
          group.visit!
          Page::Group::Menu.perform(&:go_to_general_settings)
          Page::Group::Settings::General.perform do |settings|
            settings.set_project_creation_level("Maintainers")
          end
        end

        it_behaves_like 'audit event', ["Changed project creation level"]
      end
    end

    def sign_in(as: nil)
      Page::Main::Menu.perform(&:sign_out_if_signed_in)
      Flow::Login.sign_in(as: as)
    end
  end
end
