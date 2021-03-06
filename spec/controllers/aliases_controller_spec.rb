describe AliasesController, type: :controller do
  let(:entity) { create(:entity_org) }
  it { should use_before_action(:authenticate_user!) }
  it { should route(:patch, '/aliases/123').to(action: :update, id: 123) }
  it { should route(:post, '/aliases').to(action: :create) }
  it { should route(:delete, '/aliases/123').to(action: :destroy, id: 123) }
  it { should route(:patch, '/aliases/123/make_primary').to(action: :make_primary, id: 123) }

  describe '#create' do
    login_user

    context 'with valid params' do
      let(:params) { { 'alias' => { 'name' => 'alt name', 'entity_id' => entity.id } } }
      let(:new_alias_post) { proc { post :create, params: params } }
      before { entity }

      it 'creates a new Alias' do
        expect { new_alias_post.call }.to change { Alias.count }.by(1)
      end

      it 'redirects to edit entity path' do
        new_alias_post.call
        expect(response).to have_http_status 302
        expect(response).to redirect_to edit_entity_path(entity)
        expect(controller).not_to set_flash[:alert]
      end
    end

    context 'with invalid params' do
      let(:bad_params) { { 'alias' => { 'entity_id' => entity.id } } }

      it 'does not create an alias' do
        entity
        expect { post :create, params: bad_params }.not_to change { Alias.count }
      end

      it 'redirects to edit entity path' do
        post :create, params: bad_params
        expect(response).to have_http_status 302
      end

      it 'sets flash' do
        post :create, params: bad_params
        expect(controller).to set_flash[:alert]
      end
    end
  end

  describe '#make_primary' do
    login_user

    before do
      @entity = build(:person)
      @alias = build(:alias, entity: @entity)
      expect(Alias).to receive(:find).with('123').and_return(@alias)
      expect(@alias).to receive(:make_primary).once.and_return(true)
    end

    it 'redirects to edit entity path' do
      patch :make_primary, params: { id: 123 }
      expect(response).to redirect_to edit_entity_path(@entity)
    end
  end

  describe '#destroy' do
    login_user
    before { @alias = create(:alias, entity_id: entity.id) }

    it 'delete one alias' do
      expect { delete :destroy, params: { id: @alias.id } }.to change { Alias.count }.by(-1)
    end

    it 'reduces entity\'s aliases by one' do
      expect { delete :destroy, params: { id: @alias.id } }
        .to change { Entity.find(entity.id).aliases.count }.by(-1)
    end

    it 'redirects to edit entity path' do
      delete :destroy, params: { id: @alias.id }
      expect(response).to redirect_to edit_entity_path(entity)
    end

    context 'primary alias' do
      before { @alias = create(:alias, entity_id: entity.id, is_primary: true) }
      it 'does not delete the alias if it is the primary alias' do
        expect { delete :destroy, params: { id: @alias.id } }.not_to change { Alias.count }
      end
    end
  end
end
