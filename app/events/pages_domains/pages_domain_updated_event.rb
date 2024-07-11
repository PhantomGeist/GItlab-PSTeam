# frozen_string_literal: true

module PagesDomains
  class PagesDomainUpdatedEvent < ::Gitlab::EventStore::Event
    def schema
      {
        'type' => 'object',
        'properties' => {
          'project_id' => { 'type' => 'integer' },
          'namespace_id' => { 'type' => 'integer' },
          'root_namespace_id' => { 'type' => 'integer' },
          'domain_id' => { 'type' => 'integer' },
          'domain' => { 'type' => 'string' }
        },
        'required' => %w[project_id namespace_id root_namespace_id]
      }
    end
  end
end
