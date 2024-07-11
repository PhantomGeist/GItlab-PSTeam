# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.work_item(id)', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :private, group: group) }
  let_it_be(:guest) { create(:user).tap { |u| group.add_guest(u) } }
  let_it_be(:developer) { create(:user).tap { |u| group.add_developer(u) } }
  let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: project.group)) }
  let_it_be(:project_work_item) do
    create(:work_item, project: project, description: '- List item', weight: 1, iteration: iteration)
  end

  let_it_be(:group_work_item) do
    create(:work_item, :group_level, namespace: group)
  end

  let(:current_user) { guest }
  let(:work_item) { project_work_item }
  let(:work_item_data) { graphql_data['workItem'] }
  let(:work_item_fields) { all_graphql_fields_for('WorkItem') }
  let(:global_id) { work_item.to_gid.to_s }

  let(:query) do
    graphql_query_for('workItem', { 'id' => global_id }, work_item_fields)
  end

  context 'when the user can read the work item' do
    context 'when querying widgets' do
      describe 'iteration widget' do
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetIteration {
                iteration {
                  id
                }
              }
            }
          GRAPHQL
        end

        context 'when iterations feature is licensed' do
          before do
            stub_licensed_features(iterations: true)

            post_graphql(query, current_user: current_user)
          end

          it 'returns widget information' do
            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'ITERATION',
                  'iteration' => {
                    'id' => work_item.iteration.to_global_id.to_s
                  }
                )
              )
            )
          end
        end

        context 'when iteration feature is unlicensed' do
          before do
            stub_licensed_features(iterations: false)

            post_graphql(query, current_user: current_user)
          end

          it 'returns without iteration' do
            expect(work_item_data['widgets']).not_to include(
              hash_including('type' => 'ITERATION')
            )
          end
        end
      end

      describe 'progress widget' do
        let_it_be(:objective) { create(:work_item, :objective, project: project) }
        let_it_be(:progress) { create(:progress, work_item: objective) }
        let(:global_id) { objective.to_gid.to_s }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetProgress {
                progress
                updatedAt
                currentValue
                startValue
                endValue
              }
            }
          GRAPHQL
        end

        context 'when okrs feature is licensed' do
          before do
            stub_licensed_features(okrs: true)

            post_graphql(query, current_user: current_user)
          end

          it 'returns widget information' do
            expect(objective&.work_item_type&.base_type).to match('objective')
            expect(work_item_data).to include(
              'id' => objective.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'PROGRESS',
                  'progress' => objective.progress.progress,
                  'updatedAt' => objective.progress.updated_at&.iso8601,
                  'currentValue' => objective.progress.current_value,
                  'startValue' => objective.progress.start_value,
                  'endValue' => objective.progress.end_value
                )
              )
            )
          end
        end

        context 'when okrs feature is unlicensed' do
          before do
            stub_licensed_features(okrs: false)

            post_graphql(query, current_user: current_user)
          end

          it 'returns without progress' do
            expect(objective&.work_item_type&.base_type).to match('objective')
            expect(work_item_data['widgets']).not_to include(
              hash_including(
                'type' => 'PROGRESS'
              )
            )
          end
        end
      end

      describe 'weight widget' do
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetWeight {
                weight
              }
            }
          GRAPHQL
        end

        context 'when issuable weights is licensed' do
          before do
            stub_licensed_features(issue_weights: true)

            post_graphql(query, current_user: current_user)
          end

          it 'returns widget information' do
            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'WEIGHT',
                  'weight' => work_item.weight
                )
              )
            )
          end
        end

        context 'when issuable weights is unlicensed' do
          before do
            stub_licensed_features(issue_weights: false)

            post_graphql(query, current_user: current_user)
          end

          it 'returns without weight' do
            expect(work_item_data['widgets']).not_to include(
              hash_including(
                'type' => 'WEIGHT'
              )
            )
          end
        end
      end

      describe 'status widget' do
        let_it_be(:work_item) { create(:work_item, :requirement, project: project) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetStatus {
                status
              }
            }
          GRAPHQL
        end

        context 'when requirements is licensed' do
          before do
            stub_licensed_features(requirements: true)

            post_graphql(query, current_user: current_user)
          end

          shared_examples 'response with status information' do
            it 'returns correct data' do
              expect(work_item_data).to include(
                'id' => work_item.to_gid.to_s,
                'widgets' => include(
                  hash_including(
                    'type' => 'STATUS',
                    'status' => status
                  )
                )
              )
            end
          end

          context 'when latest test report status is satisfied' do
            let_it_be(:test_report) { create(:test_report, requirement_issue: work_item, state: :passed) }

            it_behaves_like 'response with status information' do
              let(:status) { 'satisfied' }
            end
          end

          context 'when latest test report status is failed' do
            let_it_be(:test_report) { create(:test_report, requirement_issue: work_item, state: :failed) }

            it_behaves_like 'response with status information' do
              let(:status) { 'failed' }
            end
          end

          context 'with no test report' do
            it_behaves_like 'response with status information' do
              let(:status) { 'unverified' }
            end
          end
        end

        context 'when requirements is unlicensed' do
          before do
            stub_licensed_features(requirements: false)

            post_graphql(query, current_user: current_user)
          end

          it 'returns no status information' do
            expect(work_item_data['widgets']).not_to include(
              hash_including(
                'type' => 'STATUS'
              )
            )
          end
        end
      end

      describe 'test reports widget' do
        let_it_be(:work_item) { create(:work_item, :requirement, project: project) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetTestReports {
                testReports {
                  nodes {
                    id
                  }
                }
              }
            }
          GRAPHQL
        end

        context 'when requirements is licensed' do
          let_it_be(:test_report1) { create(:test_report, requirement_issue: work_item) }
          let_it_be(:test_report2) { create(:test_report, requirement_issue: work_item) }

          before do
            stub_licensed_features(requirements: true)

            post_graphql(query, current_user: current_user)
          end

          it 'returns correct widget data' do
            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'TEST_REPORTS',
                  'testReports' => {
                    'nodes' => array_including(
                      { 'id' => test_report1.to_global_id.to_s },
                      { 'id' => test_report2.to_global_id.to_s }
                    )
                  }
                )
              )
            )
          end
        end

        context 'when requirements is not licensed' do
          before do
            post_graphql(query, current_user: current_user)
          end

          it 'returns empty widget data' do
            expect(work_item_data['widgets']).not_to include(
              hash_including(
                'type' => 'TEST_REPORTS'
              )
            )
          end
        end
      end

      describe 'labels widget' do
        let(:labels) { create_list(:label, 2, project: project) }
        let(:work_item) { create(:work_item, project: project, labels: labels) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetLabels {
                allowsScopedLabels
                labels {
                  nodes {
                    id
                    title
                  }
                }
              }
            }
          GRAPHQL
        end

        where(:has_scoped_labels_license) do
          [true, false]
        end

        with_them do
          it 'returns widget information' do
            stub_licensed_features(scoped_labels: has_scoped_labels_license)

            post_graphql(query, current_user: current_user)

            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'LABELS',
                  'allowsScopedLabels' => has_scoped_labels_license,
                  'labels' => {
                    'nodes' => match_array(
                      labels.map { |a| { 'id' => a.to_gid.to_s, 'title' => a.title } }
                    )
                  }
                )
              )
            )
          end
        end
      end

      describe 'legacy requirement widget' do
        let_it_be(:work_item) { create(:work_item, :requirement, project: project) }

        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetRequirementLegacy {
                type
                legacyIid
              }
            }
          GRAPHQL
        end

        context 'when requirements is licensed' do
          before do
            stub_licensed_features(requirements: true)

            post_graphql(query, current_user: current_user)
          end

          it 'returns correct data' do
            expect(work_item_data).to include(
              'id' => work_item.to_gid.to_s,
              'widgets' => include(
                hash_including(
                  'type' => 'REQUIREMENT_LEGACY',
                  'legacyIid' => work_item.requirement.iid
                )
              )
            )
          end
        end

        context 'when requirements is unlicensed' do
          before do
            stub_licensed_features(requirements: false)

            post_graphql(query, current_user: current_user)
          end

          it 'returns no legacy requirement information' do
            expect(work_item_data['widgets']).not_to include(
              hash_including(
                'type' => 'REQUIREMENT_LEGACY',
                'legacyIid' => work_item.requirement.iid
              )
            )
          end
        end
      end

      describe 'notes widget' do
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetNotes {
                system: discussions(filter: ONLY_ACTIVITY, first: 10) { nodes { id  notes { nodes { id system internal body } } } },
                comments: discussions(filter: ONLY_COMMENTS, first: 10) { nodes { id  notes { nodes { id system internal body } } } },
                all_notes: discussions(filter: ALL_NOTES, first: 10) { nodes { id  notes { nodes { id system internal body } } } }
              }
            }
          GRAPHQL
        end

        it 'fetches notes that require gitaly call to parse note' do
          # this 9 digit long weight triggers a gitaly call when parsing the system note
          create(:resource_weight_event, user: current_user, issue: work_item, weight: 123456789)

          post_graphql(query, current_user: current_user)

          expect_graphql_errors_to_be_empty
        end

        context 'when fetching description version diffs' do
          shared_examples 'description change diff' do |description_diffs_enabled: true|
            it 'returns previous description change diff' do
              post_graphql(query, current_user: developer)

              # check that system note is added
              note = find_note(work_item, 'changed the description') # system note about changed description
              expect(work_item.reload.description).to eq('updated description')
              expect(note.note).to eq('changed the description')

              # check that diff is returned
              all_widgets = graphql_dig_at(work_item_data, :widgets)
              notes_widget = all_widgets.find { |x| x["type"] == "NOTES" }

              system_notes = graphql_dig_at(notes_widget["system"], :nodes)
              description_changed_note = graphql_dig_at(system_notes.first["notes"], :nodes).first
              description_version = graphql_dig_at(description_changed_note['systemNoteMetadata'], :descriptionVersion)

              id = GitlabSchema.parse_gid(description_version['id'], expected_type: ::DescriptionVersion).model_id
              diff = description_version['diff']
              diff_path = description_version['diffPath']
              delete_path = description_version['deletePath']
              can_delete = description_version['canDelete']
              deleted = description_version['deleted']

              url_helpers = ::Gitlab::Routing.url_helpers
              url_args = [work_item.project, work_item, id]

              if description_diffs_enabled
                expect(diff).to eq("<span class=\"idiff addition\">updated description</span>")
                expect(diff_path).to eq(url_helpers.description_diff_project_issue_path(*url_args))
                expect(delete_path).to eq(url_helpers.delete_description_version_project_issue_path(*url_args))
                expect(can_delete).to be true
              else
                expect(diff).to be_nil
                expect(diff_path).to be_nil
                expect(delete_path).to be_nil
                expect(can_delete).to be_nil
              end

              expect(deleted).to be false
            end

            def find_note(work_item, starting_with)
              work_item.notes.find do |note|
                break note if note && note.note.start_with?(starting_with)
              end
            end
          end

          let_it_be_with_reload(:work_item) { create(:work_item, project: project) }

          let(:work_item_fields) do
            <<~GRAPHQL
              id
              widgets {
                type
                ... on WorkItemWidgetNotes {
                  system: discussions(filter: ONLY_ACTIVITY, first: 10) {
                    nodes {
                      id
                      notes {
                        nodes {
                          id
                          system
                          internal
                          body
                          systemNoteMetadata {
                            id
                            descriptionVersion {
                              id
                              diff(versionId: #{version_gid})
                              diffPath
                              deletePath
                              canDelete
                              deleted
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            GRAPHQL
          end

          let(:version_gid) { "null" }
          let(:opts) { {} }
          let(:widget_params) { { description_widget: { description: "updated description" } } }

          let(:service) do
            WorkItems::UpdateService.new(
              container: project,
              current_user: developer,
              params: opts,
              widget_params: widget_params
            )
          end

          before do
            service.execute(work_item)
          end

          it_behaves_like 'description change diff'

          context 'with passed description version id' do
            let(:version_gid) { "\"#{work_item.description_versions.first.to_global_id}\"" }

            it_behaves_like 'description change diff'
          end

          context 'with description_diffs disabled' do
            before do
              stub_licensed_features(description_diffs: false)
            end

            it_behaves_like 'description change diff', description_diffs_enabled: false
          end

          context 'with description_diffs enabled' do
            before do
              stub_licensed_features(description_diffs: true)
            end

            it_behaves_like 'description change diff', description_diffs_enabled: true
          end
        end
      end

      describe 'linked items widget' do
        using RSpec::Parameterized::TableSyntax

        let_it_be(:related_item) { create(:work_item, project: project) }
        let_it_be(:blocked_item) { create(:work_item, project: project) }
        let_it_be(:blocking_item) { create(:work_item, project: project) }
        let_it_be(:link1) do
          create(:work_item_link, source: project_work_item, target: related_item, link_type: 'relates_to')
        end

        let_it_be(:link2) do
          create(:work_item_link, source: project_work_item, target: blocked_item, link_type: 'blocks')
        end

        let_it_be(:link3) do
          create(:work_item_link, source: blocking_item, target: project_work_item, link_type: 'blocks')
        end

        let(:filter_type) { 'RELATED' }
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              type
              ... on WorkItemWidgetLinkedItems {
                blocked
                blockedByCount
                blockingCount
                linkedItems(filter: #{filter_type}) {
                  nodes {
                    linkId
                    linkType
                    linkCreatedAt
                    linkUpdatedAt
                    workItem {
                      id
                    }
                  }
                }
              }
            }
          GRAPHQL
        end

        context 'when request is successful' do
          where(:filter_type, :item, :link, :expected) do
            'RELATED'    | ref(:related_item)  | ref(:link1) | 'relates_to'
            'BLOCKS'     | ref(:blocked_item)  | ref(:link2) | 'blocks'
            'BLOCKED_BY' | ref(:blocking_item) | ref(:link3) | 'is_blocked_by'
          end

          with_them do
            it 'returns widget information' do
              post_graphql(query, current_user: current_user)

              expect(work_item_data).to include(
                'widgets' => include(
                  hash_including(
                    'type' => 'LINKED_ITEMS',
                    'blocked' => true,
                    'blockedByCount' => 1,
                    'blockingCount' => 1,
                    'linkedItems' => { 'nodes' => match_array(
                      [
                        hash_including(
                          'linkId' => link.to_gid.to_s, 'linkType' => expected,
                          'linkCreatedAt' => link.created_at.iso8601, 'linkUpdatedAt' => link.updated_at.iso8601,
                          'workItem' => { 'id' => item.to_gid.to_s }
                        )
                      ]
                    ) }
                  )
                )
              )
            end
          end

          it 'avoids N+1 queries', :use_sql_query_cache do
            post_graphql(query, current_user: current_user) # warmup
            control_count = ActiveRecord::QueryRecorder.new(skip_cached: false) do
              post_graphql(query, current_user: current_user)
            end

            create_list(:work_item, 3, project: project) do |item|
              create(:work_item_link, source: item, target: work_item, link_type: 'blocks')
            end

            expect { post_graphql(query, current_user: current_user) }.to issue_same_number_of_queries_as(control_count)
            expect_graphql_errors_to_be_empty
          end
        end

        context 'when work item belongs to a group' do
          let(:work_item) { group_work_item }

          before do
            create(:work_item_link, source: work_item, target: related_item, link_type: 'relates_to')
            create(:work_item_link, source: work_item, target: blocked_item, link_type: 'blocks')
            create(:work_item_link, source: blocking_item, target: work_item, link_type: 'blocks')
          end

          it 'returns widget information' do
            post_graphql(query, current_user: current_user)

            expect(work_item_data).to include(
              'widgets' => include(
                hash_including(
                  'type' => 'LINKED_ITEMS',
                  'blocked' => true,
                  'blockedByCount' => 1,
                  'blockingCount' => 1
                )
              )
            )
          end
        end

        context 'when `linked_work_items` feature flag is disabled' do
          before do
            stub_feature_flags(linked_work_items: false)
          end

          it 'returns null fields' do
            post_graphql(query, current_user: current_user)
            expect(work_item_data).to include(
              'widgets' => include(
                hash_including(
                  'type' => 'LINKED_ITEMS',
                  'blocked' => nil,
                  'blockedByCount' => nil,
                  'blockingCount' => nil,
                  'linkedItems' => { 'nodes' => [] }
                )
              )
            )
          end
        end
      end

      describe 'hierarchy widget' do
        let_it_be(:other_group) { create(:group, :public) }
        let_it_be(:ancestor1) { create(:work_item, :epic, namespace: other_group) }
        let_it_be(:ancestor2) { create(:work_item, :epic, namespace: group) }
        let_it_be(:parent_epic) { create(:work_item, :epic, project: project) }
        let_it_be(:epic) { create(:work_item, :epic, project: project) }
        let_it_be(:child_issue1) { create(:work_item, :issue, project: project) }
        let_it_be(:child_issue2) { create(:work_item, :issue, project: project) }

        let(:current_user) { developer }
        let(:global_id) { epic.to_gid.to_s }
        let(:work_item_fields) do
          <<~GRAPHQL
            id
            widgets {
              ... on WorkItemWidgetHierarchy {
                parent {
                  id
                  webUrl
                }
                children {
                  nodes {
                    id
                    webUrl
                  }
                }
                ancestors {
                  nodes {
                    id
                  }
                }
              }
            }
          GRAPHQL
        end

        before do
          create(:parent_link, work_item_parent: ancestor2, work_item: ancestor1)
          create(:parent_link, work_item_parent: ancestor1, work_item: parent_epic)
          create(:parent_link, work_item_parent: parent_epic, work_item: epic)
          create(:parent_link, work_item_parent: epic, work_item: child_issue1)
          create(:parent_link, work_item_parent: epic, work_item: child_issue2)
        end

        it 'returns widget information' do
          post_graphql(query, current_user: current_user)

          expect(work_item_data).to include(
            'id' => epic.to_gid.to_s,
            'widgets' => include(
              hash_including(
                'parent' => {
                  'id' => parent_epic.to_gid.to_s,
                  'webUrl' => "#{Gitlab.config.gitlab.url}/#{project.full_path}/-/work_items/#{parent_epic.iid}"
                },
                'children' => { 'nodes' => match_array(
                  [
                    hash_including(
                      'id' => child_issue1.to_gid.to_s,
                      'webUrl' => "#{Gitlab.config.gitlab.url}/#{project.full_path}/-/issues/#{child_issue1.iid}"
                    ),
                    hash_including(
                      'id' => child_issue2.to_gid.to_s,
                      'webUrl' => "#{Gitlab.config.gitlab.url}/#{project.full_path}/-/issues/#{child_issue2.iid}"
                    )
                  ]) },
                'ancestors' => { 'nodes' => match_array(
                  [
                    hash_including('id' => ancestor2.to_gid.to_s),
                    hash_including('id' => ancestor1.to_gid.to_s),
                    hash_including('id' => parent_epic.to_gid.to_s)
                  ]
                ) }
              )
            )
          )
        end

        it 'avoids N+1 queries', :use_sql_query_cache do
          post_graphql(query, current_user: current_user) # warm-up

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            post_graphql(query, current_user: current_user)
          end
          expect_graphql_errors_to_be_empty

          ancestor3 = create(:work_item, :epic, namespace: create(:group))
          ancestor4 = create(:work_item, :epic, project: create(:project))
          create(:parent_link, work_item_parent: ancestor4, work_item: ancestor3)
          create(:parent_link, work_item_parent: ancestor3, work_item: ancestor2)

          expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
        end

        context 'when user does not have access to an ancestor' do
          let(:work_item_fields) do
            <<~GRAPHQL
              widgets {
                ... on WorkItemWidgetHierarchy {
                  ancestors {
                    nodes {
                      id
                    }
                  }
                }
              }
            GRAPHQL
          end

          before do
            other_group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
          end

          it 'truncates ancestors up to the last visible one' do
            post_graphql(query, current_user: current_user)

            expect(work_item_data).to include(
              'widgets' => include(
                hash_including(
                  'ancestors' => { 'nodes' => match_array(
                    [
                      hash_including('id' => parent_epic.to_gid.to_s)
                    ]
                  ) }
                )
              )
            )
          end
        end
      end
    end
  end
end
