# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::MarkDroppedAsResolvedWorker, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, user: user) }
  let_it_be(:dropped_identifiers) do
    create_list(:vulnerabilities_identifier, 7, external_type: 'find_sec_bugs_type', external_id: 'PREDICTABLE_RANDOM')
  end

  let_it_be(:dropped_identifier) { dropped_identifiers.first }
  let_it_be(:batch_size) { 1 }

  let_it_be(:dismissable_vulnerability) do
    finding = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id, primary_identifier_id: dropped_identifier.id, identifiers: [dropped_identifier]
    )

    create(:vulnerability, :detected, resolved_on_default_branch: true, project_id: pipeline.project_id).tap do |vuln|
      finding.update!(vulnerability_id: vuln.id)
    end
  end

  let_it_be(:dismissable_vulnerability_2) do
    finding = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id,
      primary_identifier_id: dropped_identifiers.last.id,
      identifiers: [dropped_identifiers.last]
    )

    create(:vulnerability, :detected, resolved_on_default_branch: true, project_id: pipeline.project_id).tap do |vuln|
      finding.update!(vulnerability_id: vuln.id)
    end
  end

  # `resolved_on_default_branch` is false which voids the
  # eligibility for resolving the vulnerability
  let_it_be(:non_dismissable_vulnerability) do
    finding = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id, primary_identifier_id: dropped_identifier.id, identifiers: [dropped_identifier]
    )

    create(:vulnerability, :detected, resolved_on_default_branch: false, project_id: pipeline.project_id).tap do |vuln|
      finding.update!(vulnerability_id: vuln.id)
    end
  end

  describe "#perform" do
    let(:worker) { described_class.new }

    before do
      stub_const("#{described_class}::BATCH_SIZE", batch_size)
    end

    include_examples 'an idempotent worker' do
      let(:subject) { worker.perform(pipeline.project_id, dropped_identifiers) }

      it 'iterates over dropped_identifier_ids in batches' do
        expect(worker).to receive(:vulnerability_ids_for).exactly(7).times.and_call_original
        expect(::Vulnerability).to receive(:transaction).twice

        subject
      end

      it 'changes state of dismissable vulnerabilities to resolved' do
        expect { subject }.to change { dismissable_vulnerability.reload.state }
          .from('detected')
          .to('resolved')
          .and change { dismissable_vulnerability.reload.resolved_by_id }
          .from(nil)
          .to(Users::Internal.security_bot.id)
      end

      it 'creates state transition entry with note for each vulnerability' do
        expect { subject }.to change(::Vulnerabilities::StateTransition, :count)
          .from(0)
          .to(2)
          .and change(Note, :count)
          .by(2)

        [dismissable_vulnerability, dismissable_vulnerability_2].each do |vuln|
          transition = ::Vulnerabilities::StateTransition.where(vulnerability_id: vuln.id).last
          expect(transition.to_state).to eq("resolved")
          expect(transition.author_id).to eq(Users::Internal.security_bot.id)
          expect(transition.comment).to match(/automatically resolved/)
        end
      end

      it 'includes a link to documentation on SAST rules changes' do
        expect { subject }.to change(::Vulnerabilities::StateTransition, :count)
          .from(0)
          .to(2)
          .and change(Note, :count)
          .by(2)

        [dismissable_vulnerability, dismissable_vulnerability_2].each do |vuln|
          transition = ::Vulnerabilities::StateTransition.where(vulnerability_id: vuln.id).last
          expect(transition.comment).to eq(
            "This vulnerability was automatically resolved because its vulnerability type was disabled " \
            "in this project or removed from GitLab's default ruleset. " \
            "For details about SAST rule changes, " \
            "see https://docs.gitlab.com/ee/user/application_security/sast/rules#important-rule-changes."
          )
        end
      end

      it 'retains same state of the non-dissmissable vulnerabilities' do
        expect(non_dismissable_vulnerability.reload.state).to eq("detected")
        expect(non_dismissable_vulnerability.reload.resolved_by_id).to eq(nil)
      end
    end
  end
end
