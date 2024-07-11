# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestVulnerabilities::Create, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, user: user) }
  let_it_be(:report_finding) { create(:ci_reports_security_finding) }
  let_it_be(:finding_map) { create(:finding_map, :with_finding, report_finding: report_finding) }
  let(:vulnerability) { Vulnerability.last }

  subject { described_class.new(pipeline, [finding_map]).execute }

  context 'vulnerability CVSS vectors' do
    let(:expected_hash) do
      { "vector_string" => "CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:L/I:L/A:N", "vendor" => "GitLab" }
    end

    it 'set the CVSS vectors' do
      subject

      expect(vulnerability.cvss.first).to eq(expected_hash)
    end
  end

  context 'vulnerability state' do
    it 'sets the state of the vulnerability to `detected`' do
      subject

      expect(vulnerability.state).to eq('detected')
    end
  end
end
