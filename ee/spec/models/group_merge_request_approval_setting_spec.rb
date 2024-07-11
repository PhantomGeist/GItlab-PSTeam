# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupMergeRequestApprovalSetting do
  describe 'Associations' do
    it { is_expected.to belong_to :group }
  end

  describe 'Validations' do
    let_it_be(:setting) { create(:group_merge_request_approval_setting) }

    subject { setting }

    options = [true, false]
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_inclusion_of(:allow_author_approval).in_array(options) }
    it { is_expected.to validate_inclusion_of(:allow_committer_approval).in_array(options) }
    it { is_expected.to validate_inclusion_of(:allow_overrides_to_approver_list_per_merge_request).in_array(options) }
    it { is_expected.to validate_inclusion_of(:retain_approvals_on_push).in_array(options) }
    it { is_expected.to validate_inclusion_of(:require_password_to_approve).in_array(options) }
  end

  describe '.find_or_initialize_by_group' do
    let_it_be(:group) { create(:group) }

    subject { described_class.find_or_initialize_by_group(group) }

    context 'with no existing setting' do
      it { is_expected.to be_a_new_record }
    end

    context 'with existing setting' do
      let_it_be(:setting) { create(:group_merge_request_approval_setting, group: group) }

      it { is_expected.to eq(setting) }
    end
  end
end
