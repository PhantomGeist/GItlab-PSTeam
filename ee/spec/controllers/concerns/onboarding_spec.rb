# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  let(:user) { build_stubbed(:user) }

  describe '.user_onboarding_in_progress?' do
    where(
      user?: [true, false],
      user_onboarding?: [true, false],
      com?: [true, false]
    )

    with_them do
      let(:local_user) { user? ? user : nil }
      let(:expected_result) { user_onboarding? && user? && com? }

      before do
        allow(user).to receive(:onboarding_in_progress?).and_return(user_onboarding?)
        allow(Gitlab).to receive(:com?).and_return(com?)
      end

      subject { described_class.user_onboarding_in_progress?(local_user) }

      it { is_expected.to be expected_result }
    end
  end
end
