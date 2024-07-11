# frozen_string_literal: true

RSpec.configure do |config|
  config.around(:each, :real_ai_request) do |example|
    real_ai_request_bool = ActiveModel::Type::Boolean.new.cast(ENV['REAL_AI_REQUEST'])

    if !real_ai_request_bool || !ENV['ANTHROPIC_API_KEY'] || !ENV['VERTEX_AI_CREDENTIALS'] || !ENV['VERTEX_AI_PROJECT']
      puts "skipping '#{example.description}' because it does real third-party requests, set " \
           "REAL_AI_REQUEST=true, ANTHROPIC_API_KEY='<key>', VERTEX_AI_CREDENTIALS=<credentials json> " \
           "and VERTEX_AI_PROJECT=<project-id>"
      next
    end

    with_net_connect_allowed do
      example.run
    end
  end

  config.before(:each, :real_ai_request) do
    allow(Gitlab::CurrentSettings.current_application_settings).to receive(:anthropic_api_key)
      .at_least(:once).and_return(ENV['ANTHROPIC_API_KEY'])
    allow(Gitlab::CurrentSettings.current_application_settings).to receive(:vertex_ai_credentials)
      .at_least(:once).and_return(ENV['VERTEX_AI_CREDENTIALS'])
    allow(Gitlab::CurrentSettings.current_application_settings).to receive(:vertex_ai_project)
      .at_least(:once).and_return(ENV['VERTEX_AI_PROJECT'])
  end

  config.before(:context, :ai_embedding_fixtures) do
    add_vertex_embeddings_from_fixture unless ::Embedding::Vertex::GitlabDocumentation.any?
  end

  def add_vertex_embeddings_from_fixture
    fixture_path = Rails.root.join("ee/spec/fixtures/vertex_embeddings")
    embedding_model = ::Embedding::Vertex::GitlabDocumentation
    copy_from_statement = "COPY #{embedding_model.table_name} FROM '#{fixture_path}'"

    embedding_model.connection.execute(copy_from_statement)
  end
end
