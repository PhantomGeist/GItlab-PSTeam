# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::API::Entities::MemberRole do
  describe 'exposes expected fields' do
    let_it_be(:group) { create(:group) }
    let_it_be(:owner) { create(:group_member, :owner, source: group) }

    let(:member_role) { create(:member_role) }
    let(:entity) { described_class.new(member_role) }

    subject { entity.as_json }

    it 'exposes the attributes' do
      expect(subject[:id]).to eq member_role.id
      expect(subject[:name]).to eq member_role.name
      expect(subject[:description]).to eq member_role.description
      expect(subject[:base_access_level]).to eq member_role.base_access_level
      expect(subject[:read_code]).to eq member_role.read_code
      expect(subject[:read_vulnerability]).to eq member_role.read_vulnerability
      expect(subject[:admin_vulnerability]).to eq member_role.admin_vulnerability
      expect(subject[:manage_project_access_tokens]).to eq member_role.admin_vulnerability
      expect(subject[:group_id]).to eq(member_role.namespace.id)
    end
  end
end
