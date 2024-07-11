# frozen_string_literal: true

require 'spec_helper'
require 'email_spec'

RSpec.describe Emails::InProductMarketing, feature_category: :instance_resiliency do
  include EmailSpec::Matchers
  include Gitlab::Routing.url_helpers

  let_it_be(:user) { create(:user) }

  it 'has correct custom headers' do
    headers = {
      from: 'GitLab <team@gitlab.com>',
      reply_to: 'GitLab <team@gitlab.com>',
      'X-Mailgun-Track' => 'yes',
      'X-Mailgun-Track-Clicks' => 'yes',
      'X-Mailgun-Track-Opens' => 'yes',
      'X-Mailgun-Tag' => 'marketing'
    }

    expect(described_class::FROM_ADDRESS).to be('GitLab <team@gitlab.com>')
    expect(described_class::CUSTOM_HEADERS).to eq(headers)
  end

  describe '#account_validation_email' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:project) { create(:project, :repository, namespace: namespace) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

    subject { Notify.account_validation_email(pipeline, user.notification_email_or_default) }

    it 'sends to the right user with a link to unsubscribe' do
      expect(subject).to deliver_to(user.notification_email_or_default)
    end

    it 'has the correct subject and content' do
      message = Gitlab::Email::Message::AccountValidation.new(pipeline)
      cta_url = project_pipeline_validate_account_url(pipeline.project, pipeline)
      cta2_url = 'https://docs.gitlab.com/runner/install/'

      aggregate_failures do
        is_expected.to have_subject(message.subject_line)
        is_expected.to have_body_text(message.title)
        is_expected.to have_body_text(message.body_line1)
        is_expected.to have_body_text(CGI.unescapeHTML(message.body_line2))
        is_expected.to have_body_text(CGI.unescapeHTML(message.cta_link))
        is_expected.to have_body_text(CGI.unescapeHTML(message.cta2_link))
        is_expected.to have_body_text(cta_url)
        is_expected.to have_body_text(cta2_url)
      end
    end
  end
end
