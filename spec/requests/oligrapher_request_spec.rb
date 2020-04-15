require 'rails_helper'
require Rails.root.join('app/services/oligrapher_lock_service.rb').to_s

describe "Oligrapher", type: :request do
  let(:user) { create_basic_user }

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
      expect(JSON.parse(response.body)['id']).to be_a Integer
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
    let(:network_map) { create(:network_map_version3, user_id: user.id) }

    context 'when logged in' do
      before { login_as(user, scope: :user) }

      after { logout(user) }

      it 'updates title' do
        expect do
          patch "/oligrapher/#{network_map.id}", params: { "attributes" => { "title" => "new title" } }
        end.to change { NetworkMap.find(network_map.id).title }.from("network map").to("new title")
        expect(response.status).to eq 200
      end
    end
  end

  describe 'editors' do
    let(:map_owner) { create_basic_user }
    let(:other_user) { create_basic_user }
    let(:network_map) do
      create(:network_map_version3, user_id: map_owner.id, editors: [map_owner.id, other_user.id])
    end

    before { network_map }

    describe 'GET /oligrapher/:id/editors' do
      describe 'as map owner' do
        before { login_as(map_owner, scope: :user) }

        after { logout(map_owner) }

        specify do
          get editors_oligrapher_path(network_map)
          expect(response.status).to eq 200
          expect(json.to_set).to eql [map_owner.username, other_user.username].to_set
        end
      end

      describe 'as other user' do
        before { login_as(other_user, scope: :user) }

        after { logout(other_user) }

        specify do
          get editors_oligrapher_path(network_map)
          expect(response).to have_http_status(403)
        end
      end
    end

    describe 'post /oligrapher/:id/editors' do
      before { login_as(map_owner, scope: :user) }

      after { logout(map_owner) }

      it 'adds an editor' do
        new_user = create_basic_user
        expect(network_map.editors).not_to include new_user.id
        post editors_oligrapher_path(network_map), params: { editor: { action: 'ADD', username: new_user.username } }
        expect(response).to have_http_status(200)
        expect(network_map.reload.editors).to include new_user.id
      end

      it 'removes an editor' do
        expect(network_map.editors).to include other_user.id
        post editors_oligrapher_path(network_map), params: { editor: { action: 'REMOVE', username: other_user.username } }
        expect(response).to have_http_status(200)
        expect(network_map.reload.editors).not_to include other_user.id
      end
    end
  end

  describe "Locking" do
    let(:owner) { create_basic_user }
    let(:editor) { create_basic_user }
    let(:map) do
      create(:network_map_version3, user_id: owner.id, editors: [owner.id, editor.id])
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
        expect(json['username']).to eq owner.username
      end
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
        expect(json['user_has_lock']).to be true
        expect(json['username']).to eq owner.username
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
        expect(json['username']).to eq owner.username
        post lock_oligrapher_path(map)
        expect(json['locked']).to be true
        expect(json['user_has_lock']).to be true
        expect(json['username']).to eq editor.username
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

    before { entity1; entity2; rel; }

    it 'responds with bad request if missing query' do
      get '/oligrapher/find_nodes', params: {}
      expect(response).to have_http_status 400
    end

    it 'renders json with node and edge data if connections are found' do
      get '/oligrapher/find_connections', params: { entity_id: entity1.id }
      expect(response).to have_http_status 200
      expect(json.length).to eq 1
      expect(json.first['id']).to eq entity2.id.to_s
      expect(json.first['edge']['id']).to eq rel.id
      expect(json.first['edge']['dash']).to eq true
      expect(json.first['edge']['arrow']).to eq '1->2'
    end
  end

  describe 'get_edges' do
    let(:entity1) { create(:entity_person) }
    let(:entity2) { create(:entity_person) }
    let(:entity3) { create(:entity_person) }

    let(:rel1) { create(:donation_relationship, entity: entity1, related: entity2, is_current: false) }
    let(:rel2) { create(:donation_relationship, entity: entity3, related: entity1, is_current: true) }

    before { entity1; entity2; entity3; rel1; rel2; }

    it 'responds with bad request if entity1_id param' do
      get '/oligrapher/get_edges', params: { entity2_ids: [entity2.id, entity3.id] }
      expect(response).to have_http_status 400
    end

    it 'responds with bad request if entity2_ids param' do
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
      expect(json.first['id']).to eq rel1.id
      expect(json.first['node1_id']).to eq entity1.id
      expect(json.first['node2_id']).to eq entity2.id
      expect(json.first['dash']).to eq true
      expect(json.first['arrow']).to eq '1->2'
      expect(json.first['url']).to eq "http://localhost:8080/relationships/#{rel1.id}"
      expect(json.second['id']).to eq rel2.id
      expect(json.second['node1_id']).to eq entity3.id
      expect(json.second['node2_id']).to eq entity1.id
      expect(json.second['dash']).to eq false
      expect(json.second['arrow']).to eq '1->2'
      expect(json.second['url']).to eq "http://localhost:8080/relationships/#{rel2.id}"
    end
  end
end
