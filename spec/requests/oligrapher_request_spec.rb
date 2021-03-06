require 'rails_helper'
require Rails.root.join('app/services/oligrapher_lock_service.rb').to_s

describe "Oligrapher", type: :request do
  let(:user) { create_basic_user }

  describe 'GET /oligrapher' do
    let(:user1) { create_basic_user }
    let(:user2) { create_basic_user }
    let(:network_map) { create(:network_map_version3, user_id: user1.id, is_private: true) }

    context 'when logged in as normal non-owner user' do
      before { login_as(user2, scope: :user) }
      after { logout(:user) }

      it 'private map cannot be viewed' do
        get "/oligrapher/#{network_map.to_param}"
        expect(response.status).to eq 403
      end
    end

    context 'when logged in as owner' do
      before { login_as(user1, scope: :user) }
      after { logout(:user) }

      it 'private map can be viewed' do
        get "/oligrapher/#{network_map.to_param}"
        expect(response.status).to eq 200
      end
    end

    it 'redirects to path with slug' do
      get "/oligrapher/#{network_map.id}"
      expect(response).to redirect_to(oligrapher_path(network_map))
    end
  end

  describe 'GET /oligrapher/new' do
    let(:user) { create_basic_user }
    before { login_as(user, scope: :user) }

    it 'shows page' do
      get "/oligrapher/new"
      expect(response.status).to eq 200
    end
  end

  describe 'POST /oligrapher' do
    before { login_as(user, scope: :user) }

    after { logout(:user) }

    let(:graph_data) do
      JSON.parse <<-JSON
       {
         "nodes": {
         "EI-H6Mvz": {
           "id": "EI-H6Mvz",
           "name": "abc",
           "x": -72.5,
           "y": -10.5,
           "scale": 1,
           "status": "normal",
           "type": "circle",
           "image": null,
           "url": null,
           "color": "#ccc"
         }
       },
       "edges": {},
       "captions": {}
      }
     JSON
    end

    let(:params) do
      {
        "graph_data" => graph_data,
        "attributes" => {
          "title" => "example title",
          "description" => "example description",
          "is_private" => false,
          "is_cloneable" => true
        }
      }
    end

    it 'creates a new NetworkMap' do
      expect { post '/oligrapher', params: params}.to change(NetworkMap, :count).by(1)
      expect(NetworkMap.last.oligrapher_version).to eq 3
      expect(NetworkMap.last.user_id).to eq user.id
    end

    it 'responds with json' do
      post '/oligrapher', params: params
      expect(response.status).to eq 200
      expect(valid_json?(response.body)).to be true
      expect(JSON.parse(response.body)['redirect_url']).to be_a String
    end

    it 'renders json of errors if invalid' do
      post '/oligrapher', params: { "graph_data" => graph_data, "attributes" => { "is_private": false } }
      expect(response.status).to eq 400
      expect(valid_json?(response.body)).to be true
      expect(json['title'][0]).to eq "can't be blank"
    end
  end

  describe 'PATCH /oligrapher/:id' do
    let(:user) { create_basic_user }
    let(:network_map) { create(:network_map_version3, user_id: user.id, settings: { "blah" => true }.to_json) }

    context 'when logged in' do
      before { login_as(user, scope: :user) }

      after { logout(user) }

      it 'updates title' do
        expect do
          patch "/oligrapher/#{network_map.id}", params: { attributes: { title: "new title" } }
        end.to change { NetworkMap.find(network_map.id).title }.from("network map").to("new title")
        expect(response.status).to eq 200
      end

      it 'updates settings' do
        expect do
          patch "/oligrapher/#{network_map.id}", params: { attributes: { settings: { blah: false }.to_json } }
        end.to change { NetworkMap.find(network_map.id).settings }.to({ blah: false }.to_json)
        expect(response.status).to eq 200
      end

      it 'updates annotations' do
        annotations_json = [
          { id: "1", title: "look at this", text: "", nodeIds: [], edgeIds: [], captionIds: [] }, 
          { id: "2", title: "look at that", text: "", nodeIds: [], edgeIds: [], captionIds: [] }
        ].to_json
        expect do
          patch "/oligrapher/#{network_map.id}", params: { attributes: { annotations_data: annotations_json } }
        end.to change { NetworkMap.find(network_map.id).annotations_data }.to(annotations_json)
        expect(response.status).to eq 200
      end
    end
  end

  describe 'POST /oligrapher/:id/clone' do
    let(:user1) { create_basic_user }
    let(:user2) { create_basic_user }
    let(:network_map) { create(:network_map_version3, user_id: user1.id) }

    context 'when logged in' do
      before { login_as(user2, scope: :user); network_map }

      after { logout(user2) }

      it 'creates a new NetworkMap' do
        expect { post "/oligrapher/#{network_map.id}/clone" }.to change(NetworkMap, :count).by(1)
        expect(NetworkMap.last.oligrapher_version).to eq 3
        expect(NetworkMap.last.user_id).to eq user2.id
        expect(NetworkMap.last.graph_data).to eq network_map.graph_data
      end

      it 'redirects to the created map' do
        post "/oligrapher/#{network_map.id}/clone"
        expect(response.status).to eq 200
        expect(json['redirect_url']).to eq Rails.application.routes.url_helpers.oligrapher_path(NetworkMap.last)
      end
    end

    context 'when the map is not cloneable' do
      before {
        login_as(user2, scope: :user)
        network_map.update(is_cloneable: false)
      }

      after { logout(user2) }

      it 'does not create a new NetworkMap' do
        expect { post "/oligrapher/#{network_map.id}/clone" }.to change(NetworkMap, :count).by(0)
      end

      it 'responds with unauthorized' do
        post "/oligrapher/#{network_map.id}/clone"
        expect(response.status).to eq 401
      end
    end
  end

  describe 'DELETE /oligrapher/:id' do
    let(:user1) { create_basic_user }
    let(:network_map) { create(:network_map_version3, user_id: user1.id) }

    context 'when logged in' do
      before { login_as(user1, scope: :user); network_map }

      after { logout(user1) }

      it 'deletes the map' do
        expect { delete "/oligrapher/#{network_map.id}" }.to change(NetworkMap, :count).by(-1)
      end

      it 'redirects to new map' do
        delete "/oligrapher/#{network_map.id}"
        expect(response.status).to eq 200
        expect(json['redirect_url']).to eq Rails.application.routes.url_helpers.new_oligrapher_path
      end
    end
  end

  describe 'editors' do
    let(:map_owner) { create_basic_user(username: 'owner') }
    let(:editor) { create_basic_user(username: 'editor') }
    let(:pending_user) { create_basic_user(username: 'pending') }
    let(:editors) { [
      { id: editor.id, pending: false },
      { id: pending_user.id, pending: true }
    ] }
    let(:network_map) do
      create(:network_map_version3, user_id: map_owner.id, editors: editors)
    end

    before { network_map }

    describe 'GET /oligrapher/:id/editors' do
      describe 'as map owner' do
        before { login_as(map_owner, scope: :user) }

        after { logout(map_owner) }

        specify do
          get editors_oligrapher_path(network_map)
          expect(response.status).to eq 200
          expect(json.map { |e| e["name"] }.to_set).to eql %w[editor pending].to_set
          expect(json.map { |e| e["pending"] }.to_set).to eql [true, false].to_set
        end
      end

      describe 'as editor' do
        before { login_as(editor, scope: :user) }

        after { logout(editor) }

        specify do
          get editors_oligrapher_path(network_map)
          expect(response.status).to eq 200
          expect(json.map { |hash| hash["name"] }).to eql %w[editor]
        end
      end

      describe 'as non-editor' do
        before { login_as(pending_user, scope: :user) }

        after { logout(pending_user) }

        specify do
          get editors_oligrapher_path(network_map)
          expect(response.status).to eq 200
          expect(json.map { |hash| hash["name"] }).to eql %w[editor]
        end
      end
    end

    describe 'POST /oligrapher/:id/editors' do
      context 'as map owner' do
        before { login_as(map_owner, scope: :user) }

        after { logout(map_owner) }

        it 'adds an editor' do
          new_user = create_basic_user
          expect(network_map.all_editor_ids).not_to include new_user.id
          post editors_oligrapher_path(network_map), params: { editor: { action: 'ADD', username: new_user.username } }
          expect(response).to have_http_status(200)
          expect(network_map.reload.all_editor_ids).to include new_user.id
        end

        it 'removes an editor' do
          expect(network_map.all_editor_ids).to include editor.id
          post editors_oligrapher_path(network_map), params: { editor: { action: 'REMOVE', username: editor.username } }
          expect(response).to have_http_status(200)
          expect(network_map.reload.all_editor_ids).not_to include editor.id
        end
      end
    end

    describe 'POST /oligrapher/:id/confirm_editor' do
      context 'as pending editor' do
        before { login_as(pending_user, scope: :user) }

        after { logout(pending_user) }

        it 'confirms the editor' do
          expect(network_map.all_editor_ids).to include pending_user.id
          expect(network_map.confirmed_editor_ids).not_to include pending_user.id
          post confirm_editor_oligrapher_path(network_map)
          expect(network_map.reload.confirmed_editor_ids).to include pending_user.id
        end
      end
    end
  end

  describe "Locking" do
    let(:owner) { create_basic_user }
    let(:editor) { create_basic_user }
    let(:map) do
      create(:network_map_version3, user_id: owner.id, editors: [
        { id: editor.id, pending: false }
      ])
    end

    describe 'logged in as owner' do
      before { login_as(owner, scope: :user) }
      after { logout(:user) }

      it 'GET requests locks if there is no lock' do
        expect(OligrapherLockService.new(map: map, current_user: owner).locked?).to be false
        get lock_oligrapher_path(map)
        expect(response).to have_http_status(200)
        expect(OligrapherLockService.new(map: map, current_user: owner).locked?).to be true
        expect(json['locked']).to be true
        expect(json['name']).to eq owner.username
      end
    end

    describe 'logged in as other user' do
      before { login_as(editor, scope: :user) }
      after { logout(:user) }

      it 'only post will take the lock' do
        OligrapherLockService.new(map: map, current_user: owner).lock!
        expect(OligrapherLockService.new(map: map, current_user: editor).locked?).to be true
        get lock_oligrapher_path(map)
        expect(response).to have_http_status(200)
        expect(OligrapherLockService.new(map: map, current_user: editor).locked?).to be true
        expect(json['locked']).to be true
        expect(json['user_has_lock']).to be false
        expect(json['name']).to eq owner.username
        post lock_oligrapher_path(map)
        expect(json['locked']).to be true
        expect(json['user_has_lock']).to be true
        expect(json['name']).to eq editor.username
      end
    end
  end

  describe 'find_nodes' do
    let(:image) { build(:image, is_featured: true) }
    let(:org1) { build(:org, :with_org_name, :with_org_blurb) }
    let(:org2) { build(:org, :with_org_name) }
    let(:nodes) { [org1, org2] }

    it 'responds with bad request if missing query' do
      get '/oligrapher/find_nodes', params: {}
      expect(response).to have_http_status 400
    end

    it 'renders json with descriptions and images' do
      expect(org2).to receive(:featured_image).and_return(image)
      expect(EntitySearchService).to receive(:new)
                                       .once
                                       .with(query: 'abc',
                                             fields: %w[name aliases blurb],
                                             per_page: 5)
                                       .and_return(double(:search => nodes))

      get '/oligrapher/find_nodes', params: { q: 'abc', num: '5' }

      expect(response).to have_http_status 200
      expect(json.length).to eq 2
      expect(json.map { |org| org['description'] }).to eq nodes.map(&:blurb)
      expect(json.first['image']).to be_nil
      expect(json.last['image']).not_to be_nil
    end
  end

  describe 'find_connections' do
    let(:entity1) { create(:entity_person) }
    let(:entity2) { create(:entity_person) }
    let(:rel) { create(:donation_relationship, entity: entity1, related: entity2, is_current: false) }
    let(:rel2) { create(:social_relationship, entity: entity1, related: entity2, is_current: true) }

    before { entity1; entity2; rel; rel2; }

    it 'responds with bad request if missing query' do
      get '/oligrapher/find_nodes', params: {}
      expect(response).to have_http_status 400
    end

    it 'renders json with node and edge data if connections are found' do
      get '/oligrapher/find_connections', params: { entity_id: entity1.id }
      expect(response).to have_http_status 200
      expect(json.length).to eq 1
      expect(json.first['id']).to eq entity2.id.to_s
      expect(json.first['edges'].first['id']).to eq rel.id.to_s
      expect(json.first['edges'].first['dash']).to eq true
      expect(json.first['edges'].first['arrow']).to eq '1->2'
      expect(json.first['edges'].second['id']).to eq rel2.id.to_s
      expect(json.first['edges'].second['dash']).to eq false
      expect(json.first['edges'].second['arrow']).to eq nil
    end
  end

  describe 'get_edges' do
    let(:entity1) { create(:entity_person) }
    let(:entity2) { create(:entity_person) }
    let(:entity3) { create(:entity_person) }

    let(:rel1) { create(:donation_relationship, entity: entity1, related: entity2, is_current: false) }
    let(:rel2) { create(:donation_relationship, entity: entity3, related: entity1, is_current: true) }

    before { entity1; entity2; entity3; rel1; rel2; }

    it 'responds with bad request if no entity1_id param' do
      get '/oligrapher/get_edges', params: { entity2_ids: [entity2.id, entity3.id] }
      expect(response).to have_http_status 400
    end

    it 'responds with bad request if no entity2_ids param' do
      get '/oligrapher/get_edges', params: { entity1_id: entity1.id }
      expect(response).to have_http_status 400
    end

    it 'renders json with node and edge data if connections are found' do
      get '/oligrapher/get_edges', params: { 
        entity1_id: entity1.id, 
        entity2_ids: [entity2.id, entity3.id] 
      }
      expect(response).to have_http_status 200
      expect(json.length).to eq 2
      expect(json.first['id']).to eq rel1.id.to_s
      expect(json.first['node1_id']).to eq entity1.id.to_s
      expect(json.first['node2_id']).to eq entity2.id.to_s
      expect(json.first['dash']).to eq true
      expect(json.first['arrow']).to eq '1->2'
      expect(json.first['url']).to eq "http://localhost:8080/relationships/#{rel1.id}"
      expect(json.second['id']).to eq rel2.id.to_s
      expect(json.second['node1_id']).to eq entity3.id.to_s
      expect(json.second['node2_id']).to eq entity1.id.to_s
      expect(json.second['dash']).to eq false
      expect(json.second['arrow']).to eq '1->2'
      expect(json.second['url']).to eq "http://localhost:8080/relationships/#{rel2.id}"
    end
  end

  describe 'get_interlocks' do
    let(:entity1) { create(:entity_person) }
    let(:entity2) { create(:entity_person) }
    let(:entity3) { create(:entity_person) }
    let(:entity4) { create(:entity_person) }

    # entity3 and entity4 are both interlocks, but entity4 is already on the map so should be omitted
    let(:rel1) { create(:social_relationship, entity: entity1, related: entity3) }
    let(:rel2) { create(:social_relationship, entity: entity2, related: entity3) }
    let(:rel3) { create(:social_relationship, entity: entity1, related: entity4) }
    let(:rel4) { create(:social_relationship, entity: entity2, related: entity4) }

    before { entity1; entity2; entity3; entity4; rel1; rel2; rel3; rel4 }

    it 'renders json with node and edge data if connections are found' do
      get '/oligrapher/get_interlocks', params: { 
        entity1_id: entity1.id, 
        entity2_id: entity2.id,
        entity_ids: entity4.id
      }
      expect(response).to have_http_status 200
      expect(json['nodes'].length).to eq 1
      expect(json['edges'].length).to eq 2
      expect(json['nodes'].first['id']).to eq entity3.id.to_s
      expect(json['edges'].map { |e| e['id'] }.sort).to eq [rel1.id, rel2.id].map(&:to_s).sort
    end
  end
end
