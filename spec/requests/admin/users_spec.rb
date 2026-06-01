# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Users', type: :request do
  let(:employee) { create(:user) }
  let(:admin)    { create(:user, :admin) }
  let(:target_user) { create(:user) }

  describe 'unauthenticated access' do
    it 'redirects to sign in for GET /admin/users' do
      get admin_users_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for GET /admin/users/:id' do
      get admin_user_path(target_user)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for GET /admin/users/new' do
      get new_admin_user_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for POST /admin/users' do
      post admin_users_path, params: { user: { email: 'test@example.com', password: 'Password1!', first_name: 'Test', last_name: 'User', employee_id: 'EMP001' } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for GET /admin/users/:id/edit' do
      get edit_admin_user_path(target_user)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for PATCH /admin/users/:id' do
      patch admin_user_path(target_user), params: { user: { first_name: 'Updated' } }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'authenticated as employee' do
    before { sign_in employee }

    it 'redirects with error for GET /admin/users' do
      get admin_users_path
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'redirects with error for GET /admin/users/:id' do
      get admin_user_path(target_user)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'redirects with error for GET /admin/users/new' do
      get new_admin_user_path
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'redirects with error for POST /admin/users' do
      post admin_users_path, params: { user: { email: 'test@example.com', password: 'Password1!', first_name: 'Test', last_name: 'User', employee_id: 'EMP001' } }
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'redirects with error for GET /admin/users/:id/edit' do
      get edit_admin_user_path(target_user)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'redirects with error for PATCH /admin/users/:id' do
      patch admin_user_path(target_user), params: { user: { first_name: 'Updated' } }
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end
  end

  describe 'authenticated as admin' do
    before { sign_in admin }

    describe 'GET /admin/users' do
      it 'returns 200 OK' do
        get admin_users_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'GET /admin/users/:id' do
      it 'returns 200 OK' do
        get admin_user_path(target_user)
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'GET /admin/users/new' do
      it 'returns 200 OK' do
        get new_admin_user_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'POST /admin/users' do
      let(:valid_params) do
        {
          user: {
            email: 'newuser@example.com',
            password: 'Password1!',
            password_confirmation: 'Password1!',
            first_name: 'New',
            last_name: 'User',
            employee_id: 'EMP999',
            role: :employee
          }
        }
      end

      it 'creates a user and redirects' do
        expect do
          post admin_users_path, params: valid_params
        end.to change(User, :count).by(1)

        expect(response).to redirect_to(admin_user_path(User.last))
      end

      it 're-renders new on invalid params' do
        post admin_users_path, params: { user: { email: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe 'GET /admin/users/:id/edit' do
      it 'returns 200 OK' do
        get edit_admin_user_path(target_user)
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'PATCH /admin/users/:id' do
      it 'updates the user and redirects' do
        patch admin_user_path(target_user), params: { user: { first_name: 'Updated' } }
        expect(target_user.reload.first_name).to eq('Updated')
        expect(response).to redirect_to(admin_user_path(target_user))
      end

      it 're-renders edit on invalid params' do
        patch admin_user_path(target_user), params: { user: { employee_id: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
