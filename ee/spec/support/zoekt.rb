# frozen_string_literal: true

module Zoekt
  module TestHelpers
    def ensure_zoekt_node!
      index_base_url = ENV.fetch('ZOEKT_INDEX_BASE_URL', 'http://127.0.0.1:6060')
      search_base_url = ENV.fetch('ZOEKT_SEARCH_BASE_URL', 'http://127.0.0.1:6070')
      ::Search::Zoekt::Node.find_or_create_by!(
        index_base_url: index_base_url,
        search_base_url: search_base_url
      )
    end
    module_function :ensure_zoekt_node!

    def zoekt_node
      ensure_zoekt_node!
    end
    module_function :zoekt_node

    def zoekt_truncate_index!
      ::Gitlab::Search::Zoekt::Client.truncate
    end
    module_function :zoekt_truncate_index!

    def zoekt_ensure_namespace_indexed!(namespace)
      ::Zoekt::IndexedNamespace.find_or_create_by!(node: zoekt_node, namespace: namespace.root_ancestor)
    end

    def zoekt_ensure_project_indexed!(project)
      zoekt_ensure_namespace_indexed!(project.namespace)

      project.repository.update_zoekt_index!
    end
  end
end

RSpec.configure do |config|
  config.around(:each, :zoekt) do |example|
    ::Zoekt::TestHelpers.ensure_zoekt_node!
    ::Zoekt::TestHelpers.zoekt_truncate_index!

    example.run

    ::Zoekt::TestHelpers.zoekt_truncate_index!
  end

  config.before(:each, :zoekt) do
    stub_licensed_features(zoekt_code_search: true)
  end

  config.include ::Zoekt::TestHelpers
end
