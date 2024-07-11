# frozen_string_literal: true

module Gitlab
  module Email
    module Message
      class AccountValidation
        include SafeFormatHelper
        include Gitlab::Routing

        attr_accessor :pipeline, :format

        def initialize(pipeline, format: :html)
          @pipeline = pipeline
          @format = format
        end

        def subject_line
          s_('AccountValidation|Fix your pipelines by validating your account')
        end

        def title
          s_("AccountValidation|Looks like you'll need to validate your account to use free compute minutes")
        end

        def body_line1
          s_("AccountValidation|In order to use free compute minutes on shared runners, " \
             "you'll need to validate your account using one of our verification options. " \
             "If you prefer not to, you can run pipelines by bringing your own runners and " \
             "disabling shared runners for your project.")
        end

        def body_line2
          format_options = strong_options.merge({ learn_more_link: learn_more_link })
          safe_format(
            s_("AccountValidation|Verification is required to discourage and reduce the abuse on GitLab " \
               "infrastructure. If you verify with a credit or debit card, %{strong_start}GitLab will not " \
               "charge your card, it will only be used for validation.%{strong_end} %{learn_more_link}"),
            format_options
          )
        end

        def cta_text
          s_('AccountValidation|Validate your account')
        end

        def cta2_text
          s_("AccountValidation|I'll bring my own runners")
        end

        def logo_path
          'mailers/in_product_marketing/verify-2.png'
        end

        def cta_link
          url = project_pipeline_validate_account_url(pipeline.project, pipeline)

          case format
          when :html
            ActionController::Base.helpers.link_to cta_text, url, target: '_blank', rel: 'noopener noreferrer'
          else
            [cta_text, url].join(' >> ')
          end
        end

        def cta2_link
          url = 'https://docs.gitlab.com/runner/install/'

          case format
          when :html
            ActionController::Base.helpers.link_to cta2_text, url, target: '_blank', rel: 'noopener noreferrer'
          else
            [cta2_text, url].join(' >> ')
          end
        end

        def unsubscribe
          parts = Gitlab.com? ? unsubscribe_com : unsubscribe_self_managed(nil)

          case format
          when :html
            parts.join(' ')
          else
            parts.join("\n#{' ' * 16}")
          end
        end

        def footer_links
          links = [
            [s_('InProductMarketing|Blog'), 'https://about.gitlab.com/blog'],
            [s_('InProductMarketing|Twitter'), 'https://twitter.com/gitlab'],
            [s_('InProductMarketing|Facebook'), 'https://www.facebook.com/gitlab'],
            [s_('InProductMarketing|YouTube'), 'https://www.youtube.com/channel/UCnMGQ8QHMAnVIsI3xJrihhg']
          ]
          case format
          when :html
            links.map do |text, link|
              ActionController::Base.helpers.link_to(text, link)
            end
          else
            "| #{links.map { |text, link| [text, link].join(' ') }.join('\n| ')}"
          end
        end

        def address
          safe_format(
            s_('InProductMarketing|%{strong_start}GitLab Inc.%{strong_end} 268 Bush Street, #350, ' \
               'San Francisco, CA 94104, USA'),
            strong_options
          )
        end

        private

        def learn_more_link
          link(s_('AccountValidation|Learn more.'), 'https://about.gitlab.com/blog/2021/05/17/prevent-crypto-mining-abuse/')
        end

        def unsubscribe_link
          unsubscribe_url = Gitlab.com? ? '%tag_unsubscribe_url%' : profile_notifications_url

          link(s_('InProductMarketing|unsubscribe'), unsubscribe_url)
        end

        def unsubscribe_com
          [
            s_('InProductMarketing|If you no longer wish to receive marketing emails from us,'),
            safe_format(
              s_('InProductMarketing|you may %{unsubscribe_link} at any time.'), unsubscribe_link: unsubscribe_link
            )
          ]
        end

        def unsubscribe_self_managed(preferences_link)
          [
            safe_format(
              s_('InProductMarketing|To opt out of these onboarding emails, %{unsubscribe_link}.'),
              unsubscribe_link: unsubscribe_link
            ),
            safe_format(
              s_("InProductMarketing|If you don't want to receive marketing emails directly from GitLab, " \
                 "%{marketing_preference_link}."),
              marketing_preference_link: preferences_link
            )
          ]
        end

        def strong_options
          case format
          when :html
            { strong_start: '<b>'.html_safe, strong_end: '</b>'.html_safe }
          else
            { strong_start: '', strong_end: '' }
          end
        end

        def link(text, link)
          case format
          when :html
            ActionController::Base.helpers.link_to text, link
          else
            "#{text} (#{link})"
          end
        end
      end
    end
  end
end
