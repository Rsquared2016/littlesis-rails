require 'rails_helper'

# rubocop:disable RSpec/NamedSubject

describe EntityVersionPresenter do
  with_versioning do
    let(:user) { create_really_basic_user }
    let(:entity) { create(:entity_person) }
    let(:entity_history) { EntityHistory.new(entity) }
    let(:versions) do
      entity_history.versions.as_presenters.map(&:render)
    end

    before do
      PaperTrail.request(whodunnit: user.id.to_s) { entity }
    end

    describe 'after the entity was created' do
      specify do
        version = entity_history.versions.as_presenters.first
        expect(version.render).to include 'created the entity'
      end
    end

    describe 'an extension was created and removed' do
      let(:time) { "<em>#{LsDate.pretty_print(Time.current)}</em>" }

      before do
        entity.add_extension 'Academic'
        entity.remove_extension 'Academic'
      end

      specify do
        expect(versions).to include "System added extension Academic at #{time}"
      end

      specify do
        expect(versions).to include "System removed extension Academic at #{time}"
      end
    end

    describe 'adding and removing entity from lists' do
      subject do
        entity_history.versions.as_presenters.map(&:render).join(' ')
      end

      let(:list) { create(:list) }

      before { list }

      describe 'entity was added to a list' do
        before { ListEntity.create!(list: list, entity: entity) }

        it 'has correct message' do
          expect(subject).to include 'added this entity to the list'
          expect(subject).not_to include 'removed this entity from the list'
        end
      end

      describe 'entity was added and removed from a list' do
        before do
          le = ListEntity.create!(list: list, entity: entity)
          le.destroy!
        end

        it 'has correct message' do
          expect(subject).to include 'removed this entity from the list'
          expect(subject).to include "#{list.name}</a>"
        end
      end
    end

    describe 'external links' do
      subject do
        entity_history.versions.as_presenters.map(&:render).join(' ')
      end

      describe 'adding an wikipedia link' do
        before do
          ExternalLink.create!(entity: entity, link_type: :wikipedia, link_id: 'example')
        end

        it 'has correct message' do
          expect(subject).to include 'added a wikipedia link'
        end
      end
    end

    describe '#user_link' do
      subject { entity_history.versions.as_presenters.first }

      it 'generates link for user' do
        expect(subject.send(:user_link)).to include "href=\"/users/#{user.username}\""
      end
    end
  end
end

# rubocop:enable RSpec/NamedSubject
