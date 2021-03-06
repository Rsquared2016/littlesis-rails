describe PagesController, type: :controller do
  it { is_expected.to route(:get, '/oligrapher').to(action: :oligrapher_splash) }
  it { is_expected.to route(:get, '/partypolitics').to(action: :partypolitics) }
  it { is_expected.to route(:get, '/donate').to(action: :donate) }
  it { is_expected.to route(:get, '/about').to(action: :display, page: 'about') }
  it { is_expected.not_to route(:post, '/about').to(action: :display, page: 'about') }
  it { is_expected.to route(:get, '/features').to(action: :display, page: 'features') }
  it { is_expected.not_to route(:get, '/bad_page').to(action: :display) }
  it { is_expected.to route(:get, '/pages/new').to(action: :new) }
  it { is_expected.to route(:get, '/pages/666').to(action: :show, id: '666') }
  it { is_expected.to route(:get, '/pages/666/edit').to(action: :edit, id: '666') }
  it { is_expected.to route(:get, '/pages/some_page/edit').to(action: :edit_by_name, page: 'some_page') }
  it { is_expected.to route(:get, '/pages/about/edit').to(action: :edit_by_name, page: 'about') }
  it { is_expected.to route(:patch, '/pages/666').to(action: :update, id: '666') }
  it { is_expected.to route(:post, '/pages').to(action: :create) }
  it { is_expected.to route(:get, '/pages').to(action: :index) }

  it 'has MARKDOWN constant' do
    expect(ToolkitController::MARKDOWN).to be_a(Redcarpet::Markdown)
  end

  describe '#display - GET /features' do
    before do
      Page.create!(name: 'features', title: 'features', markdown: '# features')
      get :display, params: { page: 'features' }
    end

    it { is_expected.to respond_with(200) }
  end

  describe 'create page' do
    let(:params) { { page: { name: 'new_page', title: 'this is a new page' } } }

    login_admin

    it 'creates new page' do
      expect { post :create, params: params }.to change(Page, :count).by(1)
    end
  end

  describe 'edit_by_name' do
    login_admin

    let(:page) do
      Page.create!(name: 'people', title: 'people', markdown: '# markdown')
    end

    it 'redirects to /pages/id/edit' do
      get :edit_by_name, params: { page: page.title }
      expect(response).to redirect_to("/pages/#{page.id}/edit")
    end
  end

  describe '#update' do
    login_admin
    let(:params) { { 'id' => @page.id, 'page' => { 'markdown' => '# part one' } } }

    before do
      @page = Page.create!(name: 'about', title: 'about us', markdown: '# markdown')
    end

    it 'updates markdown' do
      expect { patch :update, params: params }.to change { @page.reload.markdown }.to('# part one')
    end

    it 'redirects to display page' do
      patch :update, params: params
      expect(response).to redirect_to '/about'
    end
  end
end
