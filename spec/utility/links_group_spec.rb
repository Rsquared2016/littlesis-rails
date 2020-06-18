describe LinksGroup do
  context 'with generic links' do
    let(:rel1) { build(:generic_relationship, entity1_id: 10, entity2_id: 20) }
    let(:rel2) { build(:generic_relationship, entity1_id: 10, entity2_id: 50) }
    let(:link1) { build(:link, entity1_id: 10, entity2_id: 20, relationship: rel1, category_id: 12) }
    let(:link2) { build(:link, entity1_id: 10, entity2_id: 50, relationship: rel2, category_id: 12) }
    let(:links_group) { described_class.new([link1, link2], 'miscellaneous', 'Other Affiliations') }

    it 'sets keybord, heading and category_id' do
      expect(links_group.keyword).to eq 'miscellaneous'
      expect(links_group.heading).to eq 'Other Affiliations'
      expect(links_group.category_id).to eq 12
    end

    it 'has correct count' do
      expect(links_group.count).to eq 2
    end

    it 'links is a nested array' do
      expect(links_group.links).to be_a(Array)
      expect(links_group.links[0]).to be_a(Array)
      expect(links_group.links[0][0]).to be_a(Link)
    end

    it 'orders the data in the default order' do
      expect(links_group.links).to eq [[link1], [link2]]
    end
  end

  context 'with donation links' do
    let(:entity1) { build(:entity_person) }
    let(:rel1) { build(:donation_relationship, entity1_id: entity1.id, entity2_id: 2000, amount: 10) }
    let(:rel2) { build(:donation_relationship, entity1_id: entity1.id, entity2_id: 3000, amount: 30) }
    let(:rel3) { build(:donation_relationship, entity1_id: entity1.id, entity2_id: 3000, amount: 20) }
    let(:link1) { build(:link, entity1_id: entity1.id, entity2_id: 2000, relationship: rel1, category_id: 5) }
    let(:link2) { build(:link, entity1_id: entity1.id, entity2_id: 3000, relationship: rel2, category_id: 5) }
    let(:link3) { build(:link, entity1_id: entity1.id, entity2_id: 3000, relationship: rel3, category_id: 5) }
    let(:links_group) { described_class.new([link1, link2, link3], 'donation_recipients', 'Donation/Grant Recipients') }

    it 'has correct count' do
      expect(links_group.count).to eq 2
    end

    it 'order links by amount' do
      expect(links_group.links).to eq [[link2, link3], [link1]]
    end
  end

  describe 'link sorting' do
    let(:org) { create(:entity_org).add_extension('Business') }
    let(:person) { create(:entity_person) }
    let(:links) { SortedLinks.new(person) }
    let(:links_group) { links.send(:business_positions) }

    context 'with relationships differentiated by temporal status' do
      let!(:past_endless) do
        create(:position_relationship, entity: person, related: org, notes: 'past', is_current: false)
      end

      let!(:current_endless) do
        create(:position_relationship, entity: person, related: org, notes: 'current', is_current: true)
      end

      let!(:unknown_to_end) do
        create(:position_relationship, entity: person, related: org, notes: 'unknown', is_current: nil)
      end

      it 'sorts correctly by temporal status' do
        expect(links_group.links[0].map {|l| l.relationship.notes })
          .to match %w(current unknown past)
      end
    end

    context 'with relationships differentiated by end date' do
      let!(:endless) do
        create(:position_relationship, entity: person, related: org, notes: 'endless', end_date: nil)
      end

      let!(:ending) do
        create(:position_relationship, entity: person, related: org, notes: 'ending', end_date: 1.year.from_now.strftime('%Y-%m-%d'))
      end

      let!(:ended) do
        create(:position_relationship, entity: person, related: org, notes: 'ended', end_date: 1.year.ago.strftime('%Y-%m-%d'))
      end

      it 'sorts correctly by end date' do
        expect(links_group.links[0].map {|l| l.relationship.notes })
          .to match %w(endless ending ended)
      end
    end

    context 'with relationships differentiated by start date' do
      let!(:newest) do
        create(:position_relationship, entity: person, related: org, notes: 'newest', start_date:  1.year.ago.strftime('%Y-%m-%d'))
      end

      let!(:older) do
        create(:position_relationship, entity: person, related: org, notes: 'older', start_date: 2.years.ago.strftime('%Y-%m-%d'))
      end

      let!(:oldest) do
        create(:position_relationship, entity: person, related: org, notes: 'oldest', start_date: 3.years.ago.strftime('%Y-%m-%d'))
      end

      it 'sorts correctly by start date' do
        expect(links_group.links[0].map {|l| l.relationship.notes })
          .to match %w(newest older oldest)
      end
    end

    context 'with mixed sorting logics' do
      let!(:past_endless) do
        create(:position_relationship, entity: person, related: org, notes: 'past_endless', is_current: false)
      end

      let!(:current_to_end) do
        create(:position_relationship, entity: person, related: org, notes: 'current_to_end', is_current: true, end_date: 1.year.from_now.strftime('%Y-%m-%d'))
      end

      let!(:unknown_to_end) do
        create(:position_relationship, entity: person, related: org, notes: 'unknown_to_end', is_current: nil, end_date: 1.year.from_now.strftime('%Y-%m-%d'))
      end

      let!(:unknown_dateless) do
        create(:position_relationship, entity: person, related: org, notes: 'unknown_dateless', is_current: nil)
      end

      it 'sorts the links correctly' do
        expect(links_group.order(links_group.links[0]).map { |l| l.relationship.notes })
          .to match %w(current_to_end unknown_dateless unknown_to_end past_endless)
      end
    end
  end
end
