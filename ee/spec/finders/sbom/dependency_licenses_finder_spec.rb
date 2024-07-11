# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::DependencyLicensesFinder, feature_category: :dependency_management do
  let_it_be(:group) { create(:group) }
  let(:params) { {} }

  subject(:finder) { described_class.new(namespace: group, params: params) }

  describe "#execute" do
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:occurrence_1) { create(:sbom_occurrence, :mit, project: project) }
    let_it_be(:occurrence_2) { create(:sbom_occurrence, :apache_2, project: project) }
    let_it_be(:occurrence_3) { create(:sbom_occurrence, :mpl_2, project: project) }
    let_it_be(:occurrence_4) { create(:sbom_occurrence, :apache_2, project: project) }
    let_it_be(:occurrence_5) { create(:sbom_occurrence, :apache_2, :mpl_2, project: project) }
    let_it_be(:occurrence_6) { create(:sbom_occurrence, :apache_2, :mit, project: project) }
    let_it_be(:occurrence_7) { create(:sbom_occurrence, :mit, :mpl_2, project: project) }
    let_it_be(:occurrence_8) { create(:sbom_occurrence, project: project) }

    subject(:licenses) { finder.execute }

    it 'returns all detected licenses' do
      expect(licenses).to eq([
        {
          'spdx_identifier' => 'Apache-2.0',
          'name' => 'Apache 2.0 License',
          'url' => 'https://spdx.org/licenses/Apache-2.0.html'
        },
        {
          'spdx_identifier' => 'MIT',
          'name' => 'MIT License',
          'url' => 'https://spdx.org/licenses/MIT.html'
        },
        {
          'spdx_identifier' => 'MPL-2.0',
          'name' => 'Mozilla Public License 2.0',
          'url' => 'https://spdx.org/licenses/MPL-2.0.html'
        }
      ])
    end

    context "with more than the maximum unique licenses" do
      let(:maximum) { 10 }

      before do
        stub_const('Sbom::DependencyLicensesFinder::MAXIMUM_LICENSES', maximum)

        (maximum + 5).times do |index|
          version = index + 1
          create(:sbom_occurrence, project: project, licenses: [{
            spdx_identifier: version.to_s,
            name: "#{version} License",
            url: "https://spdx.org/licenses/#{version}.html"
          }])
        end
      end

      it "returns the maximum licenses" do
        expect(licenses.count).to eq(maximum)
      end
    end
  end
end
