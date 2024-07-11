# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::FindingsFinder, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ee_ci_pipeline, project: project) }

  let_it_be(:dependency_scan) do
    create(:security_scan, project: project, pipeline: pipeline, scan_type: 'dependency_scanning')
  end

  let_it_be(:container_scan) do
    create(:security_scan, project: project, pipeline: pipeline, scan_type: 'container_scanning')
  end

  let_it_be(:high_severity_finding) { create(:security_finding, scan: dependency_scan, severity: 'high') }
  let_it_be(:container_scanning_finding) { create(:security_finding, scan: container_scan) }
  let_it_be(:dismissed_finding) { create(:security_finding, scan: dependency_scan) }
  let_it_be(:false_positive_finding) do
    create(:security_finding, :with_finding_data, false_positive: true, scan: dependency_scan)
  end

  let_it_be(:non_false_positive_finding) do
    create(:security_finding, :with_finding_data, false_positive: false, scan: dependency_scan)
  end

  let_it_be(:fix_available_finding) { create(:security_finding, :with_finding_data, scan: dependency_scan) }
  let_it_be(:no_fix_available_finding) do
    create(:security_finding, :with_finding_data, remediation_byte_offsets: [], scan: dependency_scan)
  end

  before do
    create(:vulnerabilities_finding, :dismissed, project: project, uuid: dismissed_finding.uuid)

    create(:vulnerability_feedback, :dismissal,
      project: project,
      category: dependency_scan.scan_type,
      finding_uuid: dismissed_finding.uuid
    )
  end

  describe '#execute' do
    subject { described_class.new(project, pipeline, params).execute }

    let(:all_findings) { pipeline.security_findings }

    context 'with severity_levels' do
      let(:params) { { severity_levels: ['high'] } }

      it { is_expected.to contain_exactly(high_severity_finding) }

      context 'when it is an empty array' do
        let(:params) { { severity_levels: [] } }

        it { is_expected.to match_array(all_findings) }
      end
    end

    context 'with scanners' do
      let(:params) { { scanners: ['container_scanning'] } }

      it { is_expected.to contain_exactly(container_scanning_finding) }
    end

    context 'with undismissed findings' do
      context 'when check_dismissed is true' do
        let(:params) { { check_dismissed: true, vulnerability_states: ['new_needs_triage'] } }

        it { is_expected.to match_array(all_findings - [dismissed_finding]) }
      end

      context 'when check_dismissed is false' do
        let(:params) { { check_dismissed: false, vulnerability_states: ['new_needs_triage'] } }

        it { is_expected.to match_array(all_findings) }
      end
    end

    context 'with dismissed findings' do
      context 'when check_dismissed is true' do
        let(:params) { { check_dismissed: true, vulnerability_states: ['new_dismissed'] } }

        it { is_expected.to contain_exactly(dismissed_finding) }
      end

      context 'when check_dismissed is false' do
        let(:params) { { check_dismissed: false, vulnerability_states: ['new_dismissed'] } }

        it { is_expected.to match_array(all_findings) }
      end
    end

    context 'with false_positives true' do
      let(:params) { { false_positive: true } }

      it { is_expected.to contain_exactly(false_positive_finding) }
    end

    context 'with false_positives false' do
      let(:params) { { false_positive: false } }

      it { is_expected.to match_array(all_findings - [false_positive_finding]) }
    end

    context 'with fix_available true' do
      let(:params) { { fix_available: true } }

      it { is_expected.to contain_exactly(fix_available_finding, false_positive_finding, non_false_positive_finding) }
    end

    context 'with fix_available false' do
      let(:params) { { fix_available: false } }

      it do
        is_expected.to contain_exactly(no_fix_available_finding, high_severity_finding, container_scanning_finding,
          dismissed_finding)
      end
    end

    context 'when pipeline is empty' do
      let_it_be(:pipeline) { nil }
      let(:params) { {} }

      it { is_expected.to be_empty }
    end

    context 'with related_pipeline_ids' do
      let_it_be(:pipeline_without_scans) { create(:ee_ci_pipeline, :success, project: project) }
      let_it_be(:pipeline_with_scans) { create(:ee_ci_pipeline, :success, project: project) }

      let_it_be(:findings) do
        create_list(:security_finding, 5,
          scan: create(:security_scan, project: project, pipeline: pipeline_with_scans, status: :succeeded)
        )
      end

      let(:params) { { related_pipeline_ids: [pipeline.id, pipeline_with_scans.id, pipeline_without_scans.id] } }

      it { is_expected.to contain_exactly(*findings) }

      context 'when pipeline is empty' do
        let_it_be(:pipeline) { nil }
        let(:params) { { related_pipeline_ids: [pipeline_with_scans.id, pipeline_without_scans.id] } }

        it { is_expected.to be_empty }
      end
    end
  end
end
