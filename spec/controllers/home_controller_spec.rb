require 'rails_helper'

describe HomeController, type: :controller do
  describe 'routes' do
    it { is_expected.to route(:get, '/contact').to(action: :contact) }
    it { is_expected.to route(:post, '/contact').to(action: :contact) }
    it { is_expected.to route(:get, '/flag').to(action: :flag) }
    it { is_expected.to route(:post, '/flag').to(action: :flag) }
    it { is_expected.to route(:post, '/home/newsletter_signup').to(action: :newsletter_signup) }
  end

  describe 'GET contact' do
    before { get :contact }
    it { should respond_with(:success) }
    it { should render_template('contact') }
    it { should_not set_flash.now }
  end

  describe 'GET home/dashboard' do
    login_user

    before do
      network_maps = double('network_maps', order: [build(:network_map)])
      groups = double('groups', order: [])
      user_lists_double = double('arbitrary_name', order: [])
      edited_entities = double('edited', includes: double(order: double(limit: [])))
      expect(controller).to receive(:current_user).and_return(
        double(network_maps: network_maps),
        double(groups: groups),
        double(lists: user_lists_double),
        double(edited_entities: edited_entities))
      get :dashboard
    end

    it { should respond_with(:success) }
  end

  describe 'POST contact' do
    describe 'no name provided' do
      let(:params) { { email: 'email@email.com', message: 'hey' } }
      before { post :contact, params: params }
      it { should set_flash.now[:alert] }
      it { should render_template('contact') }
    end

    describe 'no email provided' do
      let(:params) { { name: 'me', message: 'hey' } }
      before { post :contact, params: params }
      it { should set_flash.now[:alert] }
      it { should render_template('contact') }
    end

    describe 'no message provided' do
      let(:params) { { name: 'me', email: 'email@email.com', message: '' } }
      before { post :contact, params: params }
      it { should set_flash.now[:alert] }
      it { should render_template('contact') }
      it ' assigns given name to @name' do
        expect(assigns(:name)).to eql 'me'
      end
    end

    describe 'fields filled out' do
      let(:post_params) { { name: 'me', email: 'email@email.com', message: 'hey' } }

      before do
        email = double('contact_email')
        expect(email).to receive(:deliver_later)
        expect(NotificationMailer)
          .to receive(:contact_email).with(hash_including(post_params)).and_return(email)
        post :contact, params: post_params
      end

      it { should_not set_flash.now[:alert] }
      it { should set_flash.now[:notice] }
      it { should render_template('contact') }
    end
  end

  describe '/flag' do
    describe 'GET' do
      before { get :flag }
      it { should respond_with(:success) }
      it { should render_template('flag') }
    end

    describe 'POST' do
      context 'no email provided' do
        before do
          expect(NotificationMailer).not_to receive(:flag_email)
          post :flag, params: { url: 'http://url', message: 'hey' }
        end
        it { should set_flash.now[:alert] }
        it { should render_template('flag') }
      end

      context 'no message provided' do
        before do
          expect(NotificationMailer).not_to receive(:flag_email)
          post :flag, params: { url: 'http://url', email: 'test@example.com' }
        end
        it { should set_flash.now[:alert] }
        it { should render_template('flag') }
      end

      context 'with all params' do
        let(:params) { {'url' => 'http://url', 'email' => 'test@example.com', 'message' => 'hey' } }

        before do
          expect(NotificationMailer)
            .to receive(:flag_email).with(params).and_return(double(deliver_later: nil))
          post :flag, params: { url: 'http://url', email: 'test@example.com', message: 'hey' }
        end

        it { should_not set_flash.now[:alert] }
        it { should set_flash.now[:notice] }
        it { should render_template('flag') }
      end
    end
  end
end
