# frozen_string_literal: true

class ProjectRepositoryState < ApplicationRecord
  include ShaAttribute

  sha_attribute :repository_verification_checksum
  sha_attribute :wiki_verification_checksum

  belongs_to :project, inverse_of: :repository_state

  validates :project, presence: true, uniqueness: true
end
