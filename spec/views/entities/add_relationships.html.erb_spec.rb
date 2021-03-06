describe 'entities/add_relationship.html.erb' do
  let(:user) { build(:user) }
  let(:entity) { build(:mega_corp_inc, updated_at: Time.current, last_user: user, id: rand(100)) }

  describe 'layout' do
    before do
      assign(:entity, entity)
      render
    end

    it 'has entity-info div' do
      expect(rendered).to have_css 'div#entity-info'
      expect(rendered).to have_css "div#entity-info[data-entitytype='Org']"
      expect(rendered).to have_css "div#entity-info[data-entityid='#{entity.id}']"
    end

    it 'has entity header' do
      css '#entity-name'
    end

    it 'has add relationship title section' do
      css 'h2', :text => "Create a new relationship"
      css "div.col-sm-7 p"
    end

    it 'has search-results-row' do
      expect(rendered).to have_css "#search-results-row", :count => 1
    end

    it 'has one table' do
      css "table", :count => 1
    end

    it 'has one image' do
      css "img", :count => 1
    end

    specify { css '#existing-reference-container' }
    specify { css '#new-reference-container' }
    specify { css '#similar-relationships' }
    specify { css '#create-relationship-btn' }

    it { is_expected.to render_template(partial: '_header') }
    it { is_expected.to render_template(partial: '_explain_categories_modal') }
    it { is_expected.to render_template(partial: '_new_entity_form') }
  end
end
