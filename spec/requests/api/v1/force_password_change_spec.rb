require 'rails_helper'

RSpec.describe 'Force Password Change Lifecycle', type: :request do
  let(:account_1) { create(:account) }
  let(:account_2) { create(:account) }
  let(:temp_password) { 'Temporary123!Pass' }
  let(:new_password) { 'BrandNew456!Secure' }

  let!(:agent) do
    create(
      :user,
      account: account_1,
      email: 'agent_force@example.com',
      password: temp_password,
      password_confirmation: temp_password,
      force_password_change: true,
      role: :agent
    )
  end

  before do
    create(:account_user, account: account_2, user: agent, role: :agent)
  end

  describe 'POST /auth/sign_in' do
    it 'signs in with temporary password and returns force_password_change: true' do
      post '/auth/sign_in',
           params: { email: agent.email, password: temp_password },
           as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['data']['force_password_change']).to be(true)
      expect(body['data']['accounts'].size).to eq(2)
    end
  end

  describe 'PUT /api/v1/profile' do
    let(:auth_headers) { agent.create_new_auth_token }

    it 'fails to change password if current temporary password is incorrect' do
      put '/api/v1/profile',
          params: {
            profile: {
              current_password: 'WrongPassword123!',
              password: new_password,
              password_confirmation: new_password
            }
          },
          headers: auth_headers,
          as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(agent.reload.force_password_change?).to be(true)
    end

    it 'fails to change password if new password does not meet complexity' do
      put '/api/v1/profile',
          params: {
            profile: {
              current_password: temp_password,
              password: 'weak',
              password_confirmation: 'weak'
            }
          },
          headers: auth_headers,
          as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(agent.reload.force_password_change?).to be(true)
    end

    it 'successfully updates password and clears force_password_change' do
      put '/api/v1/profile',
          params: {
            profile: {
              current_password: temp_password,
              password: new_password,
              password_confirmation: new_password
            }
          },
          headers: auth_headers,
          as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['force_password_change']).to be(false)
      expect(agent.reload.force_password_change?).to be(false)
      expect(agent.valid_password?(new_password)).to be(true)
      expect(agent.valid_password?(temp_password)).to be(false)
    end

    it 'preserves multi-workspace memberships and allows login with new password' do
      put '/api/v1/profile',
          params: {
            profile: {
              current_password: temp_password,
              password: new_password,
              password_confirmation: new_password
            }
          },
          headers: auth_headers,
          as: :json

      expect(agent.reload.accounts.pluck(:id)).to contain_exactly(account_1.id, account_2.id)

      post '/auth/sign_in',
           params: { email: agent.email, password: new_password },
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['data']['force_password_change']).to be(false)
    end
  end
end
