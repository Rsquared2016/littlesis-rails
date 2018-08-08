require 'rails_helper'

describe User do
  it { should have_db_column(:map_the_power) }
  it { should have_one(:api_token) }
  it { should have_many(:lists) }
  it { should have_many(:user_permissions) }
  it { should have_many(:user_requests) }
  it { should have_many(:reviewed_requests) }

  it 'has constant User::Edits (from module UserEdits)' do
    expect(User.const_defined?(:Edits)).to be true
  end

  it 'user has permissions class' do
    user = create_basic_user
    expect(user.permissions).to be_a Permissions
  end

  describe 'validations' do
    let(:user) { create_basic_user(username: 'unqiue2') }

    it 'validates presence of email' do
      expect(user.valid?).to be true
      expect(build(:really_basic_user, email: nil).valid?).to be false
    end

    it 'validates uniqueness of email' do
      expect(build(:really_basic_user, email: user.email).valid?). to be false
      expect(build(:really_basic_user, email: Faker::Internet.unique.email).valid?). to be true
    end

    describe 'username validation' do
      context 'valid user name' do
        let(:user) { build(:really_basic_user, username: 'f_kafka') }
        specify { expect(user.valid?).to eql true }
      end
      context 'invalid user name' do
        let(:user) { build(:really_basic_user, username: 'f.kafka') }
        specify { expect(user.valid?).to eql false }
      end
    end

    describe 'sf_guard' do
      subject { build(:user, sf_guard_user_id: rand(1000)) }
      it { should validate_uniqueness_of(:sf_guard_user_id) }
      it { should validate_presence_of(:sf_guard_user_id) }
    end
  end

  describe 'delagates first and last names to sf_guard_user_profile' do
    let!(:user) { create_really_basic_user }
    let!(:sf_profile) do
      create(:sf_guard_user_profile,
             name_first: Faker::Name.first_name,
             name_last: Faker::Name.last_name,
             user_id: user.sf_guard_user_id)
    end

    specify { expect(user.name_first).to eql sf_profile.name_first }
    specify { expect(user.name_last).to eql sf_profile.name_last }
  end

  describe 'set_default_network_id' do
    let(:user) do
      User.new(sf_guard_user_id: rand(1000),
               email: Faker::Internet.unique.email,
               username: random_username)
    end

    it 'sets default network id to be the app config default' do
      user.valid?
      expect(user.default_network_id).to eql APP_CONFIG.fetch('default_network_id')
    end
  end

  describe 'legacy_check_password' do
    let(:sf_user) { create(:sf_guard_user, salt: 'SALT', password: Digest::SHA1.hexdigest('SALTPEANUTS')) }
    let(:user) { create(:user, username: 'unique', sf_guard_user_id: sf_user.id) }

    it 'returns true for correct password' do
      expect(user.legacy_check_password('PEANUTS')).to be true
    end

    it 'returns false for incorrect password' do
      expect(user.legacy_check_password('FAKE_PEANUTS')).to be false
    end
  end

  describe 'create_default_permissions' do
    let(:sf_user) { create(:sf_guard_user, username: "user#{rand(1000)}") }
    let(:user) { create(:user, sf_guard_user_id: sf_user.id, email: "#{rand(1000)}@fake.com") }

    it 'creates contributor permission' do
      expect(user.has_legacy_permission('contributor')).to be false
      user.create_default_permissions
      expect(user.has_legacy_permission('contributor')).to be true
    end

    it 'creates editor permission' do
      expect(user.has_legacy_permission('editor')).to be false
      user.create_default_permissions
      expect(user.has_legacy_permission('editor')).to be true
    end
  end

  describe 'chat user' do
    let(:user) { build(:user) }
    describe 'create_chat_account' do
      it 'returns :existing_account if user has chatid' do
        expect(build(:user, chatid: '12345').create_chat_account).to be :existing_account
      end

      it 'creates account' do
        expect(Chat).to receive(:create_user).once.with(user)
        user.create_chat_account
      end
    end
  end

  describe '#recent_edits' do
    let(:user) { create_really_basic_user }

    it 'returns User::Edits' do
      expect(user.recent_edits).to be_a User::Edits
      expect(user.recent_edits(2)).to be_a User::Edits
    end
  end

  describe '#admin?' do
    let(:admin_user) { create_admin_user }
    let(:user) { create_really_basic_user }

    context 'is admin' do
      specify { expect(admin_user.admin?).to be true }
    end

    context 'is not admin' do
      specify { expect(user.admin?).to be false }
    end
  end

  describe '#importer?' do
    let(:importer) do
      sf_user = create(:sf_guard_user)
      SfGuardUserPermission.create!(permission_id: 8, user_id: sf_user.id)
      create(:user, sf_guard_user_id: sf_user.id)
    end
    let(:user) { create_really_basic_user }

    context 'is importer' do
      specify { expect(importer.importer?).to be true }
    end

    context 'is not importer' do
      specify { expect(user.importer?).to be false }
    end
  end

  describe '#bulker?' do
    let(:bulker) do
      sf_user = create(:sf_guard_user)
      SfGuardUserPermission.create!(permission_id: 9, user_id: sf_user.id)
      create(:user, sf_guard_user_id: sf_user.id)
    end
    let(:user) { create_really_basic_user }

    context 'is bulker' do
      specify { expect(bulker.bulker?).to be true }
    end

    context 'is not bulker' do
      specify { expect(user.bulker?).to be false }
    end
  end

  describe '#merger?' do
    let(:merger) do
      sf_user = create(:sf_guard_user)
      SfGuardUserPermission.create!(permission_id: 7, user_id: sf_user.id)
      create(:user, sf_guard_user_id: sf_user.id)
    end
    let(:user) { create_really_basic_user }

    context 'is merger' do
      specify { expect(merger.merger?).to be true }
    end

    context 'is not merger' do
      specify { expect(user.merger?).to be false }
    end
  end

  describe '#restricted?' do
    it 'returns true for restircted user' do
      expect(build(:user, is_restricted: true).restricted?).to be true
    end

    it 'returns false for unrestircted user' do
      expect(build(:user, is_restricted: false).restricted?).to be false
    end
  end

  describe 'User.derive_last_user_id_from' do
    it 'accepts strings and integer' do
      expect(User.derive_last_user_id_from('123')).to eql 123
      expect(User.derive_last_user_id_from(123)).to eql 123
    end

    it 'accepts User' do
      user = build(:user, sf_guard_user_id: 123)
      expect(User.derive_last_user_id_from(user)).to eql 123
    end

    it 'accepts SfGuardUser' do
      sf_user = build(:sf_user, id: 456)
      expect(User.derive_last_user_id_from(sf_user)).to eql 456
    end

    it 'by default it raises TypeError if provided nil' do
      expect { User.derive_last_user_id_from(nil) }
        .to raise_error(TypeError)
    end

    it 'returns system_user_id if allow_invalid is set' do
      expect { User.derive_last_user_id_from(Object.new, allow_invalid: true) }
        .not_to raise_error

      expect(User.derive_last_user_id_from(nil, allow_invalid: true)).to eq 1
    end
  end
end
