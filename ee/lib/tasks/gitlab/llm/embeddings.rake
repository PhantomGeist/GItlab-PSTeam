# frozen_string_literal: true

namespace :gitlab do
  namespace :llm do
    namespace :embeddings do
      namespace :vertex do
        desc 'Seed embeddings test database with pre-generated embeddings'
        task :seed, [] => [:environment] do |_t, _args|
          number_of_rows = 14010
          filename = "vertex_gitlab_docs.json"
          sha = 'da2fdc03eb702357c6104ab4a95ed998ae8febda'
          url = "https://gitlab.com/gitlab-org/enablement-section/tanuki-bot/-/raw/#{sha}/pgvector/vertex/#{filename}?inline=false"

          Dir.mktmpdir do |dir|
            embeddings_model = ::Embedding::Vertex::GitlabDocumentation

            file_path = download_embeddings_file(dir, filename, url)
            create_embeddings(embeddings_model, file_path, number_of_rows)
          end
        end

        desc 'Extract the embeddings for selected questions into a fixture'
        task :extract_embeddings, [] => [:environment] do |_t, _args|
          embedding_ids = extract_embeddings_to_fixture
          sql = ::Embedding::Vertex::GitlabDocumentation.select("*").where(id: embedding_ids).to_sql
          fixture_path = Rails.root.join("ee/spec/fixtures/vertex_embeddings")
          ::Embedding::Vertex::GitlabDocumentation.connection.execute("COPY (#{sql}) TO '#{fixture_path}'")

          puts "Don't forget to commit the generated `ee/spec/fixtures/vertex_embeddings`."
        end
      end
    end
  end
end

def download_embeddings_file(dir, filename, url)
  puts "> Fetching `#{filename}` file size"
  content_length = Gitlab::HTTP.head(url).headers.fetch('content-length').to_i
  file_path = "#{dir}/#{filename}"

  File.open(file_path, "wb") do |file|
    puts "> Downloading `#{filename}` containing pre-generated embeddings"
    cursor = 0
    i = 0
    Gitlab::HTTP.get(url, stream_body: true) do |fragment|
      file.write(fragment)
      cursor += fragment.length
      i += 1
      if i % 1000 == 0 || cursor == content_length
        puts "#{cursor / (2**20)}MiB (#{((cursor / content_length.to_f) * 100).round(2)}%)"
      end
    end
  end

  puts "> Download complete\n\n"

  file_path
end

def create_embeddings(embeddings_model, file_path, number_of_rows)
  puts "> #{number_of_rows} embedding records are to be created"
  embeddings_model.connection.execute("TRUNCATE TABLE #{embeddings_model.table_name}")

  File.open(file_path).each_line.with_index do |line, idx|
    attributes = ::Gitlab::Json.parse(line)
    embeddings_model.create!(attributes)

    if idx % 100 == 0 || idx == number_of_rows
      puts "#{idx}/#{number_of_rows} (#{((idx / number_of_rows.to_f) * 100).round(2)}%)"
    end
  end
end

def extract_embeddings_to_fixture
  questions = [
    "How do I change my password in GitLab",
    "How do I fork a project?",
    "How do I clone a repository?",
    "How do I create a project template?"
  ]

  questions.flat_map do |q|
    tanuki_bot_service = ::Gitlab::Llm::TanukiBot.new(current_user: User.first, question: q)
    question_embedding = tanuki_bot_service.embedding_for_question(q)
    neighbour_embeddings = tanuki_bot_service.get_nearest_neighbors(question_embedding)

    neighbour_embeddings.pluck(:id)
  end
end
