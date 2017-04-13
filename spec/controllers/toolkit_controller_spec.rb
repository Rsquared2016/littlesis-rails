require 'rails_helper'

describe ToolkitController, type: :controller do
  it { should route(:get, '/toolkit').to(action: :index) }
  it { should route(:get, '/toolkit/new').to(action: :new_page) }
  it { should route(:get, '/toolkit/some_page').to(action: :display, toolkit_page: 'some_page') }
  it { should route(:get, '/toolkit/another_page').to(action: :display, toolkit_page: 'another_page') }
  it { should route(:post, '/toolkit/create_new_page').to(action: :create_new_page) }

  describe 'display' do
    before(:all) do
      ToolkitPage.create!(name: 'interesting_facts', title: 'interesting facts')
    end

    it 'responds with 404 if page does not exist' do
      get :display, toolkit_page: 'not_a_page_yet'
      expect(response).to have_http_status(404)
    end

    it 'renders display if page exists' do
      get :display, toolkit_page: 'interesting_facts'
      expect(response).to have_http_status(200)
      expect(response).to render_template(:display)
    end

    it 'can accept page names with spaces and capitals' do
      get :display, toolkit_page: 'iNtErEsTiNg FaCtS'
      expect(response).to have_http_status(200)
      expect(response).to render_template(:display)
    end
  end

  describe '#index' do
    before do
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
    it { should render_with_layout('toolkit') }
  end

  describe '#new_page' do
    login_admin
    before { get :new_page } 
    it { should respond_with(:success) }
    it { should render_template(:new_page) }
  end

  describe '#create_new_page' do
    login_admin
    let(:good_params) { { 'toolkit_page' => { 'name' => 'some_page', 'title' => 'page title' } } }
    let(:bad_params) { { 'toolkit_page' => { 'title' => 'page title' } } }
    
    context 'good post' do
      it 'creates a new toolkit page' do
        expect { post :create_new_page, good_params }
          .to change { ToolkitPage.count }.by(1)
      end

      it 'sets last_user_id' do
        expect(ToolkitPage).to receive(:new)
                                .with(hash_including(:last_user_id => controller.current_user.id))
                                .and_return(spy('toolkit page'))
        post :create_new_page, good_params
      end
    end

    context 'bad post' do
      it 'does not create a new toolkit page' do
        expect { post :create_new_page, bad_params }
          .not_to change { ToolkitPage.count }
      end
      
      it 'renders new page' do
        post :create_new_page, bad_params
        expect(response).to render_template(:new_page)
      end
    end
  end

  describe '#markdown' do
    it 'can render markdown' do
      c = ToolkitController.new
      expect(c.send(:markdown, '# i am markdown'))
        .to eq "<h1>i am markdown</h1>\n"
    end
  end
end
