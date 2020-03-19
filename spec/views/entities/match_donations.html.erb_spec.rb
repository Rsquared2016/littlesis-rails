describe 'entities/match_donations.html.erb' do
  before(:all) do
    DatabaseCleaner.start
    @user = create(:user)
    @e = create(:entity_person, updated_at: Time.now, last_user: @user)
    @corp = create(:entity_org, name: 'mega corp')
    Relationship.create!(entity1_id: @e.id, entity2_id: @corp.id, description1: 'Overlord', category_id: 1)
  end

  after(:all) do
    DatabaseCleaner.clean
  end

  describe 'layout' do
    before do
      assign(:entity, @e)
      allow(view).to receive(:current_user).and_return(double(:admin? => false))
      render
    end

    it 'has header' do
      expect(rendered).to have_css '#entity-name'
    end

    it 'has actions' do
      expect(rendered).to have_css '#entity-edited-history'
      expect(rendered).to have_css '#actions a', :count => 3
    end

    it 'has table' do
      expect(rendered).to have_css 'table#donations-table'
    end

    describe 'About Sidebar' do
      it 'has sidebar container' do
        expect(rendered).to have_css '#about-sidebar'
      end

      it 'has name' do
        expect(rendered).to have_css '#about-sidebar h3', :text => 'Human Being'
      end

      it 'has position' do
        expect(rendered).to have_css '.row p strong', :text => 'Positions'
        expect(rendered).to have_css '.row p', :text => 'mega corp'
      end

      it 'does not have Education' do
        expect(rendered).not_to have_css '.row p strong', :text => 'Education'
      end

      it 'does not have Family' do
        expect(rendered).not_to have_css '.row p strong', :text => 'Family'
      end
    end
  end
end

