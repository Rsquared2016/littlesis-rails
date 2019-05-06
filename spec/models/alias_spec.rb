describe Alias, type: :model do
  let(:org) { create(:org, :with_org_name) }
  let(:create_alias) { proc { org.aliases.create!(name: Faker::Company.name) } }
  let(:current_user) { create_really_basic_user }

  it { should belong_to(:entity) }
  it { should validate_length_of(:name).is_at_most(200) }
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:entity_id) }

  it 'trim whitespace from name before validation' do
    a = build(:alias, name: ' company name ', entity: build(:org))
    expect(a.valid?).to be true
    expect(a.name).to eq 'company name'
  end

  it 'updates last_user_id of entity after creating' do
    as = Alias.new(entity: org, name: Faker::Company.name) { |a| a.current_user = current_user }
    expect { as.save! }.to change { org.reload.last_user_id }.to(current_user.sf_guard_user_id)
  end

  describe '#make_primary' do
    it 'returns true if the element is already the primary alias' do
      expect(build(:alias, is_primary: true).make_primary).to be true
    end

    it 'removes is_primary from current primary alias & makes this one primary' do
      org = create(:org)
      original_primary_a = org.aliases[0]
      expect(original_primary_a.is_primary?).to eql true
      new_a = org.aliases.create(name: 'other name')
      expect(org.primary_alias).to eq original_primary_a
      expect(new_a.make_primary).to be true
      expect(org.primary_alias).to eq new_a
      expect(Alias.find(original_primary_a.id).is_primary?).to eql false
    end

    it 'changes the name of the entity' do
      org = create(:org, name: 'original name')
      new_a = org.aliases.create(name: 'other name')
      expect(org.name).to eql 'original name'
      expect(new_a.make_primary).to be true
      expect(org.name).to eql 'other name'
    end
  end

  describe 'name_regex' do
    it 'returns regex if name parser can generate one' do
      expect(build(:alias, name: 'xyz', entity: build(:org)).name_regex).to be nil
      alice = build(:alias, name: 'alice the cat', entity: build(:person))
      expect(alice.name_regex).to be_a Regexp
    end
  end

  describe 'paper trail versioning' do
    with_versioning do
      before { org }

      it 'stores entity metadata with version' do
        expect { create_alias.call }.to change { PaperTrail::Version.count }.by(1)
        expect(Alias.last.versions.last.entity1_id).to eql org.id
      end

      it 'can skip versioning using without_versioning' do
        expect { Alias.without_versioning { create_alias.call } }
          .not_to change { PaperTrail::Version.count }
        # verifying that it re-enables versioning:
        expect { create_alias.call }.to change { PaperTrail::Version.count }.by(1)
      end

      it 'records destory events' do
        a = create_alias.call
        expect { a.destroy }.to change { PaperTrail::Version.count }.by(1)
      end

      it 'does not record update events' do
        a = create_alias.call
        expect { a.update!(name: Faker::Company.name) }.not_to change { PaperTrail::Version.count }
      end
    end
  end
end
