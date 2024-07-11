# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Navigation, feature_category: :global_search do
  describe '#tabs' do
    using RSpec::Parameterized::TableSyntax

    let(:user) { instance_double(User) }
    let(:project_double) { instance_double(Project) }
    let(:options) { {} }
    let(:search_navigation) { described_class.new(user: user, project: project, options: options) }

    before do
      allow(search_navigation).to receive(:can?).and_return(true)
      allow(search_navigation).to receive(:tab_enabled_for_project?).and_return(false)
      allow(search_navigation).to receive(:feature_flag_tab_enabled?).and_return(feature_flag_enabled)
    end

    subject(:tabs) { search_navigation.tabs }

    context 'for epics tab' do
      where(:feature_flag_enabled, :project, :show_epics, :condition) do
        false | nil | false | false
        false | nil | nil | false
        false | ref(:project_double) | true | false
        false | ref(:project_double) | false | false
        false | ref(:project_double) | nil | false
        false | nil | true | false
        true | nil | false | false
        true | nil | nil | false
        true | ref(:project_double) | true | false
        true | ref(:project_double) | false | false
        true | ref(:project_double) | nil | false
        true | nil | true | true
      end

      with_them do
        let(:options) { { show_epics: show_epics } }

        it 'data item condition is set correctly' do
          expect(tabs[:epics][:condition]).to eq(condition)
        end
      end
    end
  end
end
