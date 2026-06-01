# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Dashboard', type: :request do
  let(:employee) { create(:user) }
  let(:admin)    { create(:user, :admin) }

  describe 'unauthenticated access' do
    it 'redirects to sign in' do
      get admin_root_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'authenticated as employee' do
    before { sign_in employee }

    it 'redirects with error' do
      get admin_root_path
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end
  end

  describe 'authenticated as admin' do
    before { sign_in admin }

    it 'returns 200 OK' do
      get admin_root_path
      expect(response).to have_http_status(:ok)
    end
  end
end
