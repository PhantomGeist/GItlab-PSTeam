# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::RelatedWorkItemLink, feature_category: :portfolio_management do
  it_behaves_like 'includes LinkableItem concern (EE)' do
    let_it_be(:item_factory) { :work_item }
    let_it_be(:link_factory) { :work_item_link }
    let_it_be(:link_class) { described_class }
  end

  describe 'validations' do
    describe '#validate_related_link_restrictions' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:project) { create(:project) }

      def get_items(type_names = [], all_types: false, with_unsupported_types: false)
        if all_types
          %i[ticket requirement incident test_case task issue epic objective key_result]
        elsif with_unsupported_types
          type_names + %i[requirement incident test_case ticket]
        else
          type_names
        end
      end

      def restriction_error(source, target, action = 'be related to')
        format(
          "%{source_name} cannot %{action} %{target_name}",
          source_name: source.work_item_type.name.downcase.pluralize,
          target_name: target.work_item_type.name.downcase.pluralize,
          action: action
        )
      end

      where(:source_type_sym, :target_types, :valid) do
        :requirement | get_items(all_types: true)                          | false
        :objective   | get_items(with_unsupported_types: true)             | false
        :key_result  | get_items(with_unsupported_types: true)             | false
        :epic        | get_items(with_unsupported_types: true)             | false
        :objective   | get_items(%i[task issue epic objective key_result]) | true
        :key_result  | get_items(%i[task issue epic key_result])           | true
        :epic        | get_items(%i[task issue epic])                      | true
      end

      with_them do
        it 'validates the related link' do
          target_types.each do |target_type_sym|
            source_type = WorkItems::Type.default_by_type(source_type_sym)
            target_type = WorkItems::Type.default_by_type(target_type_sym)
            source = build(:work_item, work_item_type: source_type, project: project)
            target = build(:work_item, work_item_type: target_type, project: project)
            link = build(:work_item_link, source: source, target: target)
            opposite_link = build(:work_item_link, source: target, target: source)

            expect(link.valid?).to eq(valid)
            expect(opposite_link.valid?).to eq(valid)
            next if valid

            expect(link.errors.messages[:source]).to contain_exactly(restriction_error(source, target))
          end
        end
      end

      context 'when validating ability to block other items' do
        where(:source_type_sym, :target_types, :valid) do
          :requirement | get_items(all_types: true)                                   | false
          :incident    | get_items(all_types: true)                                   | false
          :test_case   | get_items(all_types: true)                                   | false
          :ticket      | get_items(all_types: true)                                   | false
          :issue       | get_items(with_unsupported_types: true)                      | false
          :epic        | get_items(with_unsupported_types: true)                      | false
          :task        | get_items(with_unsupported_types: true)                      | false
          :objective   | get_items(%i[epic issue task], with_unsupported_types: true) | false
          :key_result  | get_items(%i[epic issue task], with_unsupported_types: true) | false
          :issue       | get_items(%i[task issue epic objective key_result])          | true
          :epic        | get_items(%i[task issue epic objective key_result])          | true
          :task        | get_items(%i[task issue epic objective key_result])          | true
          :objective   | get_items(%i[objective key_result])                          | true
          :key_result  | get_items(%i[objective key_result])                          | true
        end

        with_them do
          it 'validates the blocking link' do
            target_types.each do |target_type_sym|
              source_type = WorkItems::Type.default_by_type(source_type_sym)
              target_type = WorkItems::Type.default_by_type(target_type_sym)
              source = build(:work_item, work_item_type: source_type, project: project)
              target = build(:work_item, work_item_type: target_type, project: project)
              link = build(:work_item_link, source: source, target: target, link_type: 'blocks')

              expect(link.valid?).to eq(valid)
              next if valid

              expect(link.errors.messages[:source]).to contain_exactly(restriction_error(source, target, 'block'))
            end
          end
        end
      end

      context 'when validating ability to be blocked by other items' do
        where(:source_type_sym, :target_types, :valid) do
          :requirement | get_items(all_types: true)                                        | false
          :incident    | get_items(all_types: true)                                        | false
          :test_case   | get_items(all_types: true)                                        | false
          :ticket      | get_items(all_types: true)                                        | false
          :issue       | get_items(%i[objective key_result], with_unsupported_types: true) | false
          :epic        | get_items(%i[objective key_result], with_unsupported_types: true) | false
          :task        | get_items(%i[objective key_result], with_unsupported_types: true) | false
          :objective   | get_items(with_unsupported_types: true)                           | false
          :key_result  | get_items(with_unsupported_types: true)                           | false
          :issue       | get_items(%i[task issue epic])                                    | true
          :epic        | get_items(%i[task issue epic])                                    | true
          :task        | get_items(%i[task issue epic])                                    | true
          :objective   | get_items(%i[epic issue task objective key_result])               | true
          :key_result  | get_items(%i[epic issue task objective key_result])               | true
        end

        with_them do
          it 'validates the related link' do
            target_types.each do |target_type_sym|
              source_type = WorkItems::Type.default_by_type(source_type_sym)
              target_type = WorkItems::Type.default_by_type(target_type_sym)
              source = build(:work_item, work_item_type: source_type, project: project)
              target = build(:work_item, work_item_type: target_type, project: project)

              link = build(:work_item_link, source: target, target: source, link_type: 'blocks')

              expect(link.valid?).to eq(valid)
              next if valid

              expect(link.errors.messages[:source]).to contain_exactly(restriction_error(target, source, 'block'))
            end
          end
        end
      end
    end
  end
end
