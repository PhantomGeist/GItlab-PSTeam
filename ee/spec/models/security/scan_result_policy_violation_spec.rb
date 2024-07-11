# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicyViolation, feature_category: :security_policy_management do
  let_it_be(:violation) { create(:scan_result_policy_violation) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:scan_result_policy_read) }
    it { is_expected.to belong_to(:merge_request) }
  end

  describe 'validations' do
    subject { violation }

    it { is_expected.to(validate_uniqueness_of(:scan_result_policy_id).scoped_to(%i[merge_request_id])) }
  end
end
