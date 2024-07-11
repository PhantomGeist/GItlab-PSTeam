# frozen_string_literal: true

module GitlabSubscriptions
  class AddOnPurchase < ApplicationRecord
    belongs_to :add_on, foreign_key: :subscription_add_on_id, inverse_of: :add_on_purchases
    belongs_to :namespace, optional: true
    has_many :assigned_users, class_name: 'GitlabSubscriptions::UserAddOnAssignment', inverse_of: :add_on_purchase

    validates :add_on, :expires_on, presence: true
    validates :namespace, presence: true, if: :gitlab_com?
    validates :subscription_add_on_id, uniqueness: { scope: :namespace_id }
    validates :quantity,
      presence: true,
      numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :purchase_xid,
      presence: true,
      length: { maximum: 255 }

    scope :active, -> { where('expires_on >= ?', Date.current) }
    scope :by_add_on_name, ->(name) { joins(:add_on).where(add_on: { name: name }) }
    scope :for_code_suggestions, -> { where(subscription_add_on_id: AddOn.code_suggestions.pick(:id)) }
    scope :for_user, ->(user) { where(namespace_id: user.billable_code_suggestions_root_group_ids) }

    scope :requiring_assigned_users_refresh, ->(limit) do
      # Fetches add_on_purchases whose assigned_users have not been refreshed in last 8 hours.
      # Used primarily by BulkRefreshUserAssignmentsWorker, which is scheduled every 4 hours
      # by ScheduleBulkRefreshUserAssignmentsWorker.
      for_code_suggestions
        .where("last_assigned_users_refreshed_at < ? OR last_assigned_users_refreshed_at is NULL", 8.hours.ago)
        .limit(limit)
    end

    def self.next_candidate_requiring_assigned_users_refresh
      requiring_assigned_users_refresh(1)
        .order('last_assigned_users_refreshed_at ASC NULLS FIRST')
        .lock('FOR UPDATE SKIP LOCKED')
        .includes(:namespace)
        .first
    end

    def already_assigned?(user)
      assigned_users.where(user: user).exists?
    end

    def active?
      expires_on >= Date.current
    end

    def expired?
      !active?
    end

    def delete_ineligible_user_assignments_in_batches!(batch_size: 50)
      deleted_assignments_count = 0

      return deleted_assignments_count unless valid_namespace?

      assigned_users.each_batch(of: batch_size) do |batch|
        ineligible_user_ids = batch.pluck_user_ids.to_set - eligible_user_ids_for_assignment

        deleted_assignments_count += batch.for_user_ids(ineligible_user_ids).delete_all
      end

      deleted_assignments_count
    end

    private

    # TODO: Refactor to only check 'namespace.present?', after 'group_namespace?' validation is added
    # See: https://gitlab.com/gitlab-org/gitlab/-/issues/424085#solution
    # The method is verbose to make above comment and intention clearer
    def valid_namespace?
      namespace.present? && namespace.group_namespace?
    end

    def eligible_user_ids_for_assignment
      @eligible_user_ids ||= namespace.code_suggestions_eligible_user_ids
    end

    def gitlab_com?
      ::Gitlab::CurrentSettings.should_check_namespace_plan?
    end
  end
end
