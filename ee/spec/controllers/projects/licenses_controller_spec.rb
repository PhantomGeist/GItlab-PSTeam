# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::LicensesController, feature_category: :dependency_management do
  describe "GET #index" do
    let_it_be(:project) { create(:project, :repository, :private) }
    let_it_be(:user) { create(:user) }
    let_it_be(:mit_license) { create(:software_license, :mit) }

    let(:params) { { namespace_id: project.namespace, project_id: project } }
    let(:get_licenses) { get :index, params: params, format: :json }

    before do
      sign_in(user)
    end

    include_context '"Security and Compliance" permissions' do
      let(:valid_request) { get :index, params: params }

      before_request do
        project.add_reporter(user)
      end
    end

    context 'with authorized user' do
      context 'when feature is available' do
        before do
          stub_licensed_features(license_scanning: true)
        end

        context 'with reporter' do
          before do
            project.add_reporter(user)
          end

          context "when requesting HTML" do
            subject(:get_licenses_html) { get :index, params: params }

            let_it_be(:apache_license) { create(:software_license, :apache_2_0) }
            let_it_be(:custom_license) { create(:software_license, :user_entered) }

            it 'returns the necessary licenses app data' do
              get_licenses_html

              licenses_app_data = assigns(:licenses_app_data)

              expect(response).to have_gitlab_http_status(:ok)
              expect(licenses_app_data[:project_licenses_endpoint]).to eql(controller.helpers.project_licenses_path(project, detected: true, format: :json))
              expect(licenses_app_data[:read_license_policies_endpoint]).to eql(controller.helpers.api_v4_projects_managed_licenses_path(id: project.id))
              expect(licenses_app_data[:write_license_policies_endpoint]).to eql('')
              expect(licenses_app_data[:documentation_path]).to eql(help_page_path('user/compliance/license_compliance/index'))
              expect(licenses_app_data[:empty_state_svg_path]).to eql(controller.helpers.image_path('illustrations/Dependency-list-empty-state.svg'))
              expect(licenses_app_data[:software_licenses]).to eql([apache_license.name, mit_license.name])
              expect(licenses_app_data[:project_id]).to eql(project.id)
              expect(licenses_app_data[:project_path]).to eql(controller.helpers.api_v4_projects_path(id: project.id))
              expect(licenses_app_data[:rules_path]).to eql(controller.helpers.api_v4_projects_approval_settings_rules_path(id: project.id))
              expect(licenses_app_data[:settings_path]).to eql(controller.helpers.api_v4_projects_approval_settings_path(id: project.id))
              expect(licenses_app_data[:approvals_documentation_path]).to eql(help_page_path('user/compliance/license_compliance/index', anchor: 'enabling-license-approvals-within-a-project'))
              expect(licenses_app_data[:locked_approvals_rule_name]).to eql(ApprovalRuleLike::DEFAULT_NAME_FOR_LICENSE_REPORT)
            end

            it_behaves_like 'tracks govern usage event', 'users_visiting_licenses' do
              let(:request) { get_licenses_html }
            end
          end

          it 'counts usage of the feature' do
            expect(::Gitlab::UsageDataCounters::LicensesList).to receive(:count).with(:views)

            get_licenses
          end

          context 'with existing report' do
            let_it_be(:pipeline) { create(:ee_ci_pipeline, status: :success, project: project, builds: [create(:ee_ci_build, :success, :cyclonedx)]) }

            before do
              create(:pm_package, name: "activesupport", purl_type: "gem",
                other_licenses: [{ license_names: ["MIT"], versions: ["5.1.4"] }])
              create(:pm_package, name: "github.com/sirupsen/logrus", purl_type: "golang",
                other_licenses: [{ license_names: ["MIT", "BSD-3-Clause"], versions: ["v1.4.2"] }])
              create(:pm_package, name: "org.apache.logging.log4j/log4j-api", purl_type: "maven",
                other_licenses: [{ license_names: ["BSD-3-Clause"], versions: ["2.6.1"] }])

              get_licenses
            end

            it 'returns success code' do
              expect(response).to have_gitlab_http_status(:ok)
            end

            it 'returns a hash with licenses sorted by name' do
              expect(json_response['licenses'].length).to eq(3)
              expect(json_response['licenses'][0]).to include({
                'id' => nil,
                'classification' => 'unclassified',
                'name' => 'BSD-3-Clause',
                'spdx_identifier' => "BSD-3-Clause",
                'url' => "https://spdx.org/licenses/BSD-3-Clause.html",
                # TODO: figure out if order is important here
                'components' => match_array([
                  {
                    "name" => "github.com/sirupsen/logrus",
                    "package_manager" => nil,
                    "version" => "v1.4.2",
                    "blob_path" => %r{^/namespace\d+/project-\d+/-/blob/master/go.sum$}
                  },
                  {
                    "name" => "org.apache.logging.log4j/log4j-api",
                    "package_manager" => nil,
                    "version" => "2.6.1",
                    "blob_path" => nil
                  }
                ])
              })
            end

            it 'returns status ok' do
              expect(json_response['report']['status']).to eq('ok')
            end

            it 'includes the pagination headers' do
              expect(response).to include_pagination_headers
            end

            context 'with pagination params' do
              let(:params) { { namespace_id: project.namespace, project_id: project, per_page: 2, page: 2 } }

              it 'return only 1 license' do
                expect(json_response['licenses'].length).to eq(1)
              end
            end
          end

          context "when software policies are applied to some of the most recently detected licenses" do
            let_it_be(:pipeline) { create(:ee_ci_pipeline, status: :success, project: project, builds: [create(:ee_ci_build, :success, :cyclonedx)]) }
            let_it_be(:mit_policy) { create(:software_license_policy, :denied, software_license: mit_license, project: project) }
            let_it_be(:other_license) { create(:software_license, spdx_identifier: "Other-Id") }
            let_it_be(:other_license_policy) { create(:software_license_policy, :allowed, software_license: other_license, project: project) }

            before do
              create(:pm_package, name: "activesupport", purl_type: "gem",
                other_licenses: [{ license_names: ["MIT"], versions: ["5.1.4"] }])
              create(:pm_package, name: "github.com/sirupsen/logrus", purl_type: "golang",
                other_licenses: [{ license_names: ["MIT", "BSD-3-Clause"], versions: ["v1.4.2"] }])
              create(:pm_package, name: "org.apache.logging.log4j/log4j-api", purl_type: "maven",
                other_licenses: [{ license_names: ["BSD-3-Clause"], versions: ["2.6.1"] }])

              get_licenses
            end

            context "when loading all policies" do
              before do
                get :index, params: {
                  namespace_id: project.namespace,
                  project_id: project,
                  detected: false
                }, format: :json
              end

              it { expect(response).to have_gitlab_http_status(:ok) }
              it { expect(json_response["licenses"].count).to be(4) }

              it 'sorts by name by default' do
                names = json_response['licenses'].map { |x| x['name'] }

                expect(names).to eql(['BSD-3-Clause', 'MIT', other_license.name, 'unknown'])
              end

              it 'includes a policy for an unclassified and known license that was detected in the scan report' do
                expect(json_response.dig("licenses", 0)).to include({
                  "id" => nil,
                  "spdx_identifier" => "BSD-3-Clause",
                  "name" => 'BSD-3-Clause',
                  "url" => "https://spdx.org/licenses/BSD-3-Clause.html",
                  "classification" => "unclassified"
                })
              end

              it 'includes a policy for a denied license found in the scan report' do
                expect(json_response.dig("licenses", 1)).to include({
                  "id" => mit_policy.id,
                  "spdx_identifier" => "MIT",
                  "name" => mit_license.name,
                  "url" => "https://spdx.org/licenses/MIT.html",
                  "classification" => "denied"
                })
              end

              it 'includes a policy for an allowed license NOT found in the latest scan report' do
                expect(json_response.dig("licenses", 2)).to include({
                  "id" => other_license_policy.id,
                  "spdx_identifier" => other_license.spdx_identifier,
                  "name" => other_license.name,
                  "url" => nil,
                  "classification" => "allowed"
                })
              end

              it 'includes an entry for an unclassified and unknown license found in the scan report' do
                expect(json_response.dig("licenses", 3)).to include({
                  "id" => nil,
                  "spdx_identifier" => nil,
                  "name" => "unknown",
                  "url" => nil,
                  "classification" => "unclassified"
                })
              end
            end

            context "when loading software policies that match licenses detected in the most recent license scan report" do
              before do
                get :index, params: {
                  namespace_id: project.namespace,
                  project_id: project,
                  detected: true
                }, format: :json
              end

              it { expect(response).to have_gitlab_http_status(:ok) }

              it 'only includes policies for licenses detected in the most recent scan report' do
                expect(json_response["licenses"].count).to be(3)
              end

              it 'includes an unclassified policy for a known license detected in the scan report' do
                expect(json_response.dig("licenses", 0)).to include({
                  "id" => nil,
                  "spdx_identifier" => "BSD-3-Clause",
                  "classification" => "unclassified"
                })
              end

              it 'includes a classified license for a known license detected in the scan report' do
                expect(json_response.dig("licenses", 1)).to include({
                  "id" => mit_policy.id,
                  "spdx_identifier" => "MIT",
                  "classification" => "denied"
                })
              end

              it 'includes an unclassified and unknown license discovered in the scan report' do
                expect(json_response.dig("licenses", 2)).to include({
                  "id" => nil,
                  "spdx_identifier" => nil,
                  "name" => "unknown",
                  "url" => nil,
                  "classification" => "unclassified"
                })
              end
            end

            context "when loading `allowed` software policies only" do
              before do
                get :index, params: {
                  namespace_id: project.namespace,
                  project_id: project,
                  classification: ['allowed']
                }, format: :json
              end

              it { expect(response).to have_gitlab_http_status(:ok) }
              it { expect(json_response["licenses"].count).to be(1) }

              it 'includes only `allowed` policies' do
                expect(json_response.dig("licenses", 0)).to include({
                  "id" => other_license_policy.id,
                  "spdx_identifier" => "Other-Id",
                  "classification" => "allowed"
                })
              end
            end

            context "when loading `allowed` and `denied` software policies" do
              before do
                get :index, params: {
                  namespace_id: project.namespace,
                  project_id: project,
                  classification: %w[allowed denied]
                }, format: :json
              end

              it { expect(response).to have_gitlab_http_status(:ok) }
              it { expect(json_response["licenses"].count).to be(2) }

              it 'includes `denied` policies' do
                expect(json_response.dig("licenses", 0)).to include({
                  "id" => mit_policy.id,
                  "spdx_identifier" => mit_license.spdx_identifier,
                  "classification" => mit_policy.classification
                })
              end

              it 'includes `allowed` policies' do
                expect(json_response.dig("licenses", 1)).to include({
                  "id" => other_license_policy.id,
                  "spdx_identifier" => other_license_policy.spdx_identifier,
                  "classification" => other_license_policy.classification
                })
              end
            end

            context "when loading policies ordered by `classification` in `ascending` order" do
              before do
                get :index, params: { namespace_id: project.namespace, project_id: project, sort_by: :classification, sort_direction: :asc }, format: :json
              end

              specify { expect(response).to have_gitlab_http_status(:ok) }
              specify { expect(json_response['licenses'].map { |x| x['classification'] }).to eq(%w[allowed unclassified unclassified denied]) }
            end
          end

          context 'without existing license scanning report' do
            let!(:pipeline) { create(:ee_ci_pipeline, :with_dependency_list_report, project: project) }

            before do
              get_licenses
            end

            it 'returns status job_not_set_up' do
              expect(json_response['report']['status']).to eq('job_not_set_up')
            end
          end
        end

        context 'with maintainer' do
          subject(:get_licenses_html) { get :index, params: params }

          before do
            project.add_maintainer(user)
          end

          it 'responds to an HTML request' do
            get_licenses_html

            expect(response).to have_gitlab_http_status(:ok)
            licenses_app_data = assigns(:licenses_app_data)
            expect(licenses_app_data[:project_licenses_endpoint]).to eql(controller.helpers.project_licenses_path(project, detected: true, format: :json))
            expect(licenses_app_data[:read_license_policies_endpoint]).to eql(controller.helpers.api_v4_projects_managed_licenses_path(id: project.id))
            expect(licenses_app_data[:write_license_policies_endpoint]).to eql(controller.helpers.api_v4_projects_managed_licenses_path(id: project.id))
            expect(licenses_app_data[:documentation_path]).to eql(help_page_path('user/compliance/license_compliance/index'))
            expect(licenses_app_data[:empty_state_svg_path]).to eql(controller.helpers.image_path('illustrations/Dependency-list-empty-state.svg'))
          end

          it_behaves_like 'tracks govern usage event', 'users_visiting_licenses' do
            let(:request) { get_licenses_html }
          end
        end
      end

      context 'when feature is not available' do
        it 'returns 404' do
          get_licenses

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it_behaves_like "doesn't track govern usage event", 'users_visiting_dependencies' do
          let(:request) { get_licenses }
        end
      end
    end

    context 'with unauthorized user' do
      before do
        stub_licensed_features(license_scanning: true)
      end

      it 'returns 404' do
        get_licenses

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it_behaves_like "doesn't track govern usage event", 'users_visiting_dependencies' do
        let(:request) { get_licenses }
      end
    end
  end
end
