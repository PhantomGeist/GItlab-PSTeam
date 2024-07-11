# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/_credit_card_info.html.haml', :saas, feature_category: :system_access do
  include ApplicationHelper

  let_it_be(:user, reload: true) { create(:user) }

  def render
    super(
      partial: 'admin/users/credit_card_info',
      formats: :html,
      locals: { user: user }
    )
  end

  it 'does not show validated_at date' do
    render

    expect(rendered).to have_content('Validated:')
    expect(rendered).to have_content('No')
  end

  context 'when user is validated' do
    let_it_be(:credit_card_validation) do
      create(
        :credit_card_validation,
        user: user,
        network: 'AmericanExpress',
        last_digits: 2,
        credit_card_validated_at: Date.parse('2023-09-20')
      )
    end

    it 'shows validated_at date' do
      render

      expect(rendered).to have_content('Validated at:')
      expect(rendered).to have_content('Sep 20, 2023')
    end
  end
end
