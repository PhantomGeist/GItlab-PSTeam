# frozen_string_literal: true

#----------------
# SHARED CONTEXTS
#----------------

RSpec.shared_context 'with authorized user' do
  let_it_be(:current_user) { workspace.user }
end

RSpec.shared_context 'with other user' do
  let_it_be(:other_user) { create(:user) }
end

RSpec.shared_context 'with unauthorized user as current user' do
  include_context 'with other user'

  let_it_be(:current_user) { other_user }
end

RSpec.shared_context 'in licensed environment' do
  before do
    stub_licensed_features(remote_development: true)
  end
end

RSpec.shared_context 'in unlicensed environment' do
  before do
    stub_licensed_features(remote_development: false)
  end
end

#----------------
# SHARED EXAMPLES
#----------------

RSpec.shared_examples 'query is a working graphql query' do
  before do
    post_graphql(query, current_user: current_user)
  end

  it_behaves_like 'a working graphql query'
end

RSpec.shared_examples 'query returns workspace' do
  before do
    post_graphql(query, current_user: current_user)
  end

  it { expect(subject['name']).to eq(workspace.name) }
end

RSpec.shared_examples 'query returns workspaces hash containing workspace' do
  before do
    post_graphql(query, current_user: current_user)
  end

  # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-25400
  it 'includes only the expected workspace', :unlimited_max_formatted_output_length do
    # NOTE: The assertions below are redundant, but they are kept separate so that failure messages are
    #       shorter, more informative, and more understandable.

    # 1. The result should not include unexpected non-matching workspaces
    # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    expect(subject).not_to include(a_hash_including('name' => non_matching_workspace.name))

    # 2. The result is expected to include ONLY a single matching workspace (we should never have more than one
    #    matching workspace in the fixture, it's not necessary for coverage of any relevant code path)
    #    See more context in this thread: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/134488#note_1614454570
    expect(subject.length).to eq(1)

    # 3. The workspace in the result should be the one we expect
    is_expected.to match_array(a_hash_including('name' => workspace.name))
  end
end

RSpec.shared_examples 'query returns blank' do
  before do
    post_graphql(query, current_user: current_user)
  end

  it { is_expected.to be_blank }
end

RSpec.shared_examples 'query includes graphql error' do |regexes_to_match|
  before do
    post_graphql(query, current_user: current_user)
  end

  it 'includes a graphql error' do
    expect_graphql_errors_to_include(regexes_to_match)
  end
end

RSpec.shared_examples 'query in unlicensed environment' do
  context 'when remote_development feature is unlicensed' do
    include_context 'in unlicensed environment'

    context 'when user is authorized' do
      include_context 'with authorized user'

      it_behaves_like 'query returns blank'
      it_behaves_like 'query includes graphql error', /'remote_development' licensed feature is not available/
    end
  end
end

RSpec.shared_examples 'query with feature flag off' do
  context 'when remote_development_feature_flag feature flag is disabled' do
    include_context 'in licensed environment'

    before do
      stub_feature_flags(remote_development_feature_flag: false)
    end

    context 'when user is authorized' do
      include_context 'with authorized user'

      it_behaves_like 'query returns blank'
      it_behaves_like 'query includes graphql error', /'remote_development_feature_flag' feature flag is disabled/
    end
  end
end

RSpec.shared_examples 'single workspace query' do
  context 'when remote_development feature is licensed' do
    include_context 'in licensed environment'

    context 'when user is authorized' do
      include_context 'with authorized user'

      it_behaves_like 'query is a working graphql query'
      it_behaves_like 'query returns workspace'

      context 'when the user requests a workspace that they are not authorized for' do
        let_it_be(:other_workspace) { create(:workspace) }
        let(:id) { other_workspace.to_global_id.to_s }

        it_behaves_like 'query returns blank'
      end
    end

    context 'when user is not authorized' do
      include_context 'with unauthorized user as current user'

      it_behaves_like 'query is a working graphql query'
      it_behaves_like 'query returns blank'
    end
  end

  it_behaves_like 'query in unlicensed environment'
  it_behaves_like 'query with feature flag off'
end

RSpec.shared_examples 'multiple workspaces query' do
  context 'when remote_development feature is licensed' do
    include_context 'in licensed environment'

    context 'when user is authorized' do
      include_context 'with authorized user'

      it_behaves_like 'query is a working graphql query'
      it_behaves_like 'query returns workspaces hash containing workspace'

      context 'when the user requests a workspace that they are not authorized for' do
        let_it_be(:other_workspace) { create(:workspace) }

        let(:ids) do
          [
            workspace.to_global_id.to_s,
            other_workspace.to_global_id.to_s
          ]
        end

        before do
          post_graphql(query, current_user: current_user)
        end

        it 'does not return the unauthorized workspace' do
          # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
          expect(subject).not_to include(a_hash_including('name' => other_workspace.name))
        end

        it 'still returns the authorized workspace' do
          # Note we are only doing an array_including here, not an exact match_array, because that would result in a
          # misleading failure message, and the exact array match should be covered by other tests, it's not the
          # responsibility of this authorization test.
          # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
          expect(subject).to include(a_hash_including('name' => workspace.name))
        end
      end
    end

    context 'when user is not authorized' do
      include_context 'with unauthorized user as current user'

      it_behaves_like 'query is a working graphql query'
      it_behaves_like 'query returns blank'
    end
  end

  it_behaves_like 'query in unlicensed environment'
  it_behaves_like 'query with feature flag off'
end
