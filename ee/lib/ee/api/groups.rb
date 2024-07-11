# frozen_string_literal: true

module EE
  module API
    module Groups
      extend ActiveSupport::Concern

      prepended do
        helpers do
          extend ::Gitlab::Utils::Override

          include ::Admin::IpRestrictionHelper

          override :find_groups
          # rubocop: disable CodeReuse/ActiveRecord
          def find_groups(params, parent_id = nil)
            params.delete(:repository_storage) unless can?(current_user, :change_repository_storage)

            super(params, parent_id)
              .preload(:ldap_group_links, :deletion_schedule, :saml_group_links)
          end
          # rubocop: enable CodeReuse/ActiveRecord

          override :create_group
          def create_group
            ldap_link_attrs = {
              cn: params.delete(:ldap_cn),
              group_access: params.delete(:ldap_access)
            }

            authenticated_as_admin! if params[:shared_runners_minutes_limit]

            group = super

            # NOTE: add backwards compatibility for single ldap link
            if group.persisted? && ldap_link_attrs[:cn].present?
              group.ldap_group_links.create(
                cn: ldap_link_attrs[:cn],
                group_access: ldap_link_attrs[:group_access]
              )
            end

            group
          end

          override :update_group
          def update_group(group)
            params.delete(:file_template_project_id) unless
              group.licensed_feature_available?(:custom_file_templates_for_namespace)

            params.delete(:ip_restriction_ranges) unless
              ip_restriction_feature_available?(group)

            params.delete(:prevent_forking_outside_group) unless
              can?(current_user, :change_prevent_group_forking, group)

            unless group.unique_project_download_limit_enabled?
              %i[
                unique_project_download_limit
                unique_project_download_limit_interval_in_seconds
                unique_project_download_limit_allowlist
                unique_project_download_limit_alertlist
                auto_ban_user_on_excessive_projects_download
              ].each do |param|
                params.delete(param)
              end
            end

            super
          end

          override :authorize_group_creation!
          def authorize_group_creation!
            authorize! :create_group_via_api
          end

          def check_audit_events_available!(group)
            forbidden! unless group.licensed_feature_available?(:audit_events)
          end

          def audit_event_finder_params
            params
              .slice(:created_after, :created_before)
              .then { |params| filter_by_author(params) }
          end

          def filter_by_author(params)
            can?(current_user, :admin_group, user_group) ? params : params.merge(author_id: current_user.id)
          end

          def immediately_delete_subgroup_error(group)
            if !group.subgroup?
              '`permanently_remove` option is only available for subgroups.'
            elsif !group.marked_for_deletion?
              'Group must be marked for deletion first.'
            elsif group.full_path != params[:full_path]
              '`full_path` is incorrect. You must enter the complete path for the subgroup.'
            end
          end

          def check_ssh_certificate_available_to_group(group)
            not_found!('Group') unless group
            not_found! unless ::Feature.enabled?(:ssh_certificates_rest_endpoints, group)
            not_found! unless group.licensed_feature_available?(:ssh_certificates)
            forbidden!('Group') if group.has_parent?
          end

          override :delete_group
          def delete_group(group)
            return super unless group.adjourned_deletion?

            if ::Gitlab::Utils.to_boolean(params[:permanently_remove])
              error = immediately_delete_subgroup_error(group)
              return super if error.nil?

              render_api_error!(error, 400)
            end

            result = destroy_conditionally!(group) do |group|
              ::Groups::MarkForDeletionService.new(group, current_user).execute
            end

            if result[:status] == :success
              accepted!
            else
              render_api_error!(result[:message], 400)
            end
          end
        end

        resource :groups, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
          desc 'Sync a group with LDAP.'
          post ":id/ldap_sync", feature_category: :system_access do
            not_found! unless ::Gitlab::Auth::Ldap::Config.group_sync_enabled?

            group = find_group!(params[:id])
            authorize! :admin_group, group

            if group.pending_ldap_sync
              ::LdapGroupSyncWorker.perform_async(group.id)
            end

            status 202
          end

          segment ':id/audit_events' do
            before do
              authorize! :read_group_audit_events, user_group
              check_audit_events_available!(user_group)
              increment_unique_values('a_compliance_audit_events_api', current_user.id)

              ::Gitlab::Tracking.event(
                'EE::API::Groups',
                'group_audit_event_request',
                user: current_user,
                namespace: user_group,
                context: [
                  ::Gitlab::Tracking::ServicePingContext
                    .new(data_source: :redis_hll, event: 'a_compliance_audit_events_api')
                    .to_context
                ]
              )
            end

            desc 'Get a list of audit events in this group.' do
              success EE::API::Entities::AuditEvent
              is_array true
            end
            params do
              optional :created_after,
                type: DateTime,
                desc: 'Return audit events created after the specified time',
                documentation: { type: 'dateTime', example: '2016-01-19T09:05:50.355Z' }
              optional :created_before,
                type: DateTime,
                desc: 'Return audit events created before the specified time',
                documentation: { type: 'dateTime', example: '2016-01-19T09:05:50.355Z' }

              use :pagination
            end
            get '/', feature_category: :audit_events, urgency: :low do
              level = ::Gitlab::Audit::Levels::Group.new(group: user_group)
              audit_events = AuditEventFinder.new(
                level: level,
                params: audit_event_finder_params
              ).execute

              present paginate_with_strategies(audit_events), with: EE::API::Entities::AuditEvent
            end

            desc 'Get a specific audit event in this group.' do
              success EE::API::Entities::AuditEvent
            end
            params do
              requires :audit_event_id, type: Integer, desc: 'The ID of the audit event'
            end
            get '/:audit_event_id', feature_category: :audit_events do
              level = ::Gitlab::Audit::Levels::Group.new(group: user_group)
              # rubocop: disable CodeReuse/ActiveRecord, Rails/FindById
              # This is not `find_by!` from ActiveRecord
              audit_event = AuditEventFinder.new(level: level, params: audit_event_finder_params)
                .find_by!(id: params[:audit_event_id])
              # rubocop: enable CodeReuse/ActiveRecord, Rails/FindById

              present audit_event, with: EE::API::Entities::AuditEvent
            end
          end

          desc 'Restore a group.'
          post ':id/restore', feature_category: :groups_and_projects do
            authorize! :admin_group, user_group
            break not_found! unless user_group.licensed_feature_available?(:adjourned_deletion_for_projects_and_groups)

            result = ::Groups::RestoreService.new(user_group, current_user).execute
            user_group.preload_shared_group_links

            if result[:status] == :success
              present user_group, with: ::API::Entities::GroupDetail, current_user: current_user
            else
              render_api_error!(result[:message], 400)
            end
          end

          desc 'Get a list of users provisioned by the group' do
            success ::API::Entities::UserPublic
          end
          params do
            optional :username, type: String, desc: 'Return a single user with a specific username'
            optional :search, type: String, desc: 'Search users by name, email or username'
            optional :active, type: Grape::API::Boolean, default: false, desc: 'Return only active users'
            optional :blocked, type: Grape::API::Boolean, default: false, desc: 'Return only blocked users'
            optional :created_after, type: DateTime, desc: 'Return users created after the specified time'
            optional :created_before, type: DateTime, desc: 'Return users created before the specified time'

            use :pagination
          end
          # rubocop: disable CodeReuse/ActiveRecord
          get ':id/provisioned_users', feature_category: :system_access do
            authorize! :maintainer_access, user_group

            finder = ::Auth::ProvisionedUsersFinder.new(
              current_user,
              declared_params.merge(provisioning_group: user_group))

            users = finder.execute.preload(:identities)

            present paginate(users), with: ::API::Entities::UserPublic
          end
          # rubocop: enable CodeReuse/ActiveRecord

          desc 'Get a list of ssh certificates created for a group.' do
            summary 'Get a list of Groups::SshCertificate for a Group.'
            success code: 200, model: EE::API::Entities::SshCertificate
            failure [
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: '404 Not Found' }
            ]
            is_array true
            tags %w[groups]
          end
          params do
            use :pagination
          end
          get ":id/ssh_certificates", feature_category: :groups_and_projects, urgency: :low do
            group = find_group!(params[:id])
            authorize! :admin_group, group

            check_ssh_certificate_available_to_group(group)

            present paginate(group.ssh_certificates), with: EE::API::Entities::SshCertificate
          end

          desc 'Create a ssh certificate for a group.' do
            summary 'Add a Groups::SshCertificate.'
            success code: 201, model: EE::API::Entities::SshCertificate
            failure [
              { code: 400, message: 'Bad request' },
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: 'Not found' }
            ]
            tags %w[groups]
          end
          params do
            requires :title, type: String, desc: 'The title of the ssh certificate'
            requires :key, type: String, desc: 'The key of the ssh certificate'
          end
          post ":id/ssh_certificates", feature_category: :groups_and_projects do
            group = find_group!(params[:id])
            authorize! :admin_group, group

            check_ssh_certificate_available_to_group(group)

            response = ::Groups::SshCertificates::CreateService.new(group, params, current_user).execute
            if response.success?
              present response.payload, with: EE::API::Entities::SshCertificate
            else
              render_api_error!(response.message, response.reason)
            end
          end

          desc 'Removes an ssh certificate from a group.' do
            detail 'Removes a Groups::SshCertificate'
            success code: 204
            failure [
              { code: 400, message: 'Bad request' },
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 422, message: 'Unprocessable entity' }
            ]
          end
          delete ":id/ssh_certificates/:ssh_certificates_id", feature_category: :groups_and_projects do
            group = find_group!(params[:id])
            authorize! :admin_group, group

            check_ssh_certificate_available_to_group(group)

            response = ::Groups::SshCertificates::DestroyService.new(group, params, current_user).execute

            if response.success?
              no_content!
            else
              render_api_error!(response.message, response.reason)
            end
          end
        end
      end
    end
  end
end
