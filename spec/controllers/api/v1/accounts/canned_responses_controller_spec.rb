require 'rails_helper'

RSpec.describe 'Canned Responses API', type: :request do
  let(:account) { create(:account) }

  before do
    create(:canned_response, account: account, content: 'Hey {{ contact.name }}, Thanks for reaching out', short_code: 'name-short-code')
  end

  describe 'GET /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'returns all the canned responses' do
        get "/api/v1/accounts/#{account.id}/canned_responses",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.pluck('id')).to eq(account.canned_responses.pluck(:id))
      end

      it 'returns all the canned responses the user searched for' do
        cr1 = account.canned_responses.first
        create(:canned_response, account: account, content: 'Great! Looking forward', short_code: 'short-code')
        cr2 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'content-with-thanks')
        cr3 = create(:canned_response, account: account, content: 'Thanks for reaching out', short_code: 'Thanks')

        params = { search: 'thanks' }

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.pluck('id')).to eq([cr3.id, cr2.id, cr1.id])
      end

      it 'ignores null bytes in the search string' do
        matching_response = create(:canned_response, account: account, content: 'Unique response', short_code: 'unique')

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: { search: "uni\0que" },
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.pluck('id')).to eq([matching_response.id])
      end

      it 'returns every response to administrators' do
        admin = create(:user, account: account, role: :administrator)
        other_user = create(:user, account: account, role: :agent)
        team = create(:team, account: account)
        restricted = create(:canned_response, account: account, access_scope: :specific_teams, allowed_teams: [team])
        private_response = create(:canned_response, account: account, access_scope: :only_me, creator: other_user)

        get "/api/v1/accounts/#{account.id}/canned_responses", headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.pluck('id')).to include(restricted.id, private_response.id)
      end

      it 'does not return responses assigned to another team' do
        team_a = create(:team, account: account)
        team_b = create(:team, account: account)
        create(:team_member, team: team_a, user: agent)
        visible = create(:canned_response, account: account, access_scope: :specific_teams, allowed_teams: [team_a])
        hidden = create(:canned_response, account: account, access_scope: :specific_teams, allowed_teams: [team_b])

        get "/api/v1/accounts/#{account.id}/canned_responses", headers: agent.create_new_auth_token, as: :json

        expect(response.parsed_body.pluck('id')).to include(visible.id)
        expect(response.parsed_body.pluck('id')).not_to include(hidden.id)
      end

      it 'returns a specific-users response only to a selected user' do
        selected = create(:canned_response, account: account, access_scope: :specific_users, allowed_users: [agent])

        get "/api/v1/accounts/#{account.id}/canned_responses", headers: agent.create_new_auth_token, as: :json

        expect(response.parsed_body.pluck('id')).to include(selected.id)
      end

      it 'does not return another user private response' do
        other_user = create(:user, account: account, role: :agent)
        private_response = create(:canned_response, account: account, access_scope: :only_me, creator: other_user)

        get "/api/v1/accounts/#{account.id}/canned_responses", headers: agent.create_new_auth_token, as: :json

        expect(response.parsed_body.pluck('id')).not_to include(private_response.id)
      end

      it 'applies access control to search results' do
        other_user = create(:user, account: account, role: :agent)
        hidden = create(:canned_response, account: account, short_code: 'private-search', access_scope: :only_me, creator: other_user)

        get "/api/v1/accounts/#{account.id}/canned_responses",
            params: { search: 'private-search' }, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.pluck('id')).not_to include(hidden.id)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/canned_responses' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/canned_responses"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'creates a new canned response' do
        team = create(:team, account: account)
        params = { short_code: 'short', content: 'content', access_scope: 'specific_teams', allowed_team_ids: [team.id] }

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(account.canned_responses.count).to eq(2)
        expect(account.canned_responses.last).to have_attributes(creator: agent, access_scope: 'specific_teams', allowed_team_ids: [team.id])
      end


      it 'rejects teams from another workspace' do
        other_team = create(:team)

        post "/api/v1/accounts/#{account.id}/canned_responses",
             params: { short_code: 'short', content: 'content', access_scope: 'specific_teams', allowed_team_ids: [other_team.id] },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'updates an existing canned response' do
        params = { short_code: 'B' }

        put "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
            params: params,
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(canned_response.reload.short_code).to eq('B')
      end

      it 'cannot update a response outside the visible scope' do
        other_user = create(:user, account: account, role: :agent)
        private_response = create(:canned_response, account: account, access_scope: :only_me, creator: other_user)

        put "/api/v1/accounts/#{account.id}/canned_responses/#{private_response.id}",
            params: { short_code: 'bypass' }, headers: agent.create_new_auth_token, as: :json

        expect(response).to have_http_status(:not_found)
        expect(private_response.reload.short_code).not_to eq('bypass')
      end

      it 'allows an administrator to update a response outside its assigned users' do
        admin = create(:user, account: account, role: :administrator)
        restricted = create(:canned_response, account: account, access_scope: :specific_users, allowed_users: [agent])

        put "/api/v1/accounts/#{account.id}/canned_responses/#{restricted.id}",
            params: { access_scope: 'only_me' }, headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(restricted.reload).to have_attributes(access_scope: 'only_me')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/canned_responses/:id' do
    let(:canned_response) { CannedResponse.last }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'destroys the canned response' do
        delete "/api/v1/accounts/#{account.id}/canned_responses/#{canned_response.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(CannedResponse.count).to eq(0)
      end

      it 'cannot destroy a response outside the visible scope' do
        other_user = create(:user, account: account, role: :agent)
        private_response = create(:canned_response, account: account, access_scope: :only_me, creator: other_user)

        delete "/api/v1/accounts/#{account.id}/canned_responses/#{private_response.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:not_found)
        expect(private_response.reload).to be_persisted
      end
    end
  end
end
