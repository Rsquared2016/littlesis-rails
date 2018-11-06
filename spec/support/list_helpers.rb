# frozen_string_literal: true

module ListHelpersForExampleGroups
  def test_request_for_user(x)
    it "is #{x[:response]} for #{x[:action]} by #{x[:user]}" do
      sign_in instance_variable_get(x[:user]) if x[:user].present?
      if x[:action] == :update
        patch x[:action], params: { id: '123', list: { name: 'list name' } }
      elsif x[:action] == :destroy
        delete x[:action], params: { id: '123' }
      elsif [:add_entity, :remove_entity, :update_entity].include?(x[:action])

        allow(ListEntity).to receive(:add_to_list!) if x[:action] == :add_entity
        allow(ListEntity).to receive(:remove_from_list!) if x[:action] == :remove_entity

        post x[:action], params: { id: '123', entity_id: '123', list_entity_id: '456' }
      elsif x[:action] == :create_entity_associations
        post x[:action] # { data: [{ type: 'entities', id: 1 }] }
      else
        get x[:action], params: { id: '123' }
      end

      if x[:response] == :login_redirect
        expect(response).to have_http_status 302
        expect(response.location).to include '/login'
      else
        expect(response).to have_http_status(x[:response])
      end
      
      
      sign_out instance_variable_get(x[:user]) if x[:user].present?
    end
  end
end
