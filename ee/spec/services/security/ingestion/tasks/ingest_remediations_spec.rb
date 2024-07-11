# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestRemediations, feature_category: :vulnerability_management do
  describe '#execute' do
    let(:pipeline) { create(:ci_pipeline) }
    let(:existing_diff) { 'foo' }
    let(:new_diff) { 'bar' }
    let(:project) { pipeline.project }

    let(:existing_checksum) { Digest::SHA256.hexdigest(existing_diff) }
    let(:existing_remediation_1) { create(:vulnerabilities_remediation, project: project, checksum: existing_checksum, file: Tempfile.new.tap { _1.write(existing_diff) }, summary: 'Foo Summary') }
    let(:existing_remediation_2) { create(:vulnerabilities_remediation, project: project) }

    let(:vulnerability_1) { create(:vulnerability, project: project) }
    let(:vulnerability_2) { create(:vulnerability, project: project) }

    let(:vulnerability_read_1) { Vulnerabilities::Read.where(vulnerability_id: vulnerability_1).first }
    let(:vulnerability_read_2) { Vulnerabilities::Read.where(vulnerability_id: vulnerability_2).first }

    let(:report_remediation_1) { create(:ci_reports_security_remediation, diff: existing_diff, summary: "Foo Summary") }
    let(:report_remediation_2) { create(:ci_reports_security_remediation, diff: new_diff, summary: "Bar Summary") }

    let(:finding_1) { create(:vulnerabilities_finding, vulnerability: vulnerability_1, remediations: [existing_remediation_1, existing_remediation_2]) }
    let(:finding_2) { create(:vulnerabilities_finding, vulnerability: vulnerability_2) }

    let(:report_finding_1) { create(:ci_reports_security_finding, remediations: [report_remediation_1, report_remediation_2]) }
    let(:report_finding_2) { create(:ci_reports_security_finding, remediations: [report_remediation_1, report_remediation_2]) }

    let(:finding_map_1) { create(:finding_map, finding: finding_1, report_finding: report_finding_1) }
    let(:finding_map_2) { create(:finding_map, finding: finding_2, report_finding: report_finding_2) }

    let!(:service_object) { described_class.new(pipeline, [finding_map_1, finding_map_2]) }

    subject(:ingest_finding_remediations) { service_object.execute }

    before do
      # As the first vulnerability remediations are updated instead of ingestion task above,
      # we have to update corresponding vulnerability_reads.
      vulnerability_read_1.update!(has_remediations: true)
    end

    it 'creates remediations and updates the associations' do
      expect { ingest_finding_remediations }.to change { Vulnerabilities::Remediation.count }.by(1)
                                            .and change { existing_remediation_2.reload.findings }.from([finding_1]).to([])
                                            .and change { finding_2.reload.association(:remediations).scope.count }.from(0).to(2)
                                            .and not_change { finding_1.reload.association(:remediations).scope.count }.from(2)

      expect(finding_2.remediations).to include({ "diff" => existing_diff, "summary" => "Foo Summary" }, { "summary" => "Bar Summary", "diff" => new_diff })
      expect(finding_1.remediations).to include({ "diff" => existing_diff, "summary" => "Foo Summary" }, { "summary" => "Bar Summary", "diff" => new_diff })
    end

    it 'updates vulnerability reads' do
      ingest_finding_remediations

      expect(vulnerability_read_1.reload.has_remediations).to be(false)
      expect(vulnerability_read_2.reload.has_remediations).to be(true)
    end

    it_behaves_like 'bulk insertable task'
  end
end
