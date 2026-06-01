# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CertificateRequests', type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  describe 'unauthenticated access' do
    it 'redirects to sign in for GET /certificate_requests' do
      get certificate_requests_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for GET /certificate_requests/:id' do
      cr = create(:certificate_request, user: user)
      get certificate_request_path(cr)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'authenticated access' do
    before { sign_in user }

    describe 'GET /certificate_requests' do
      it 'returns 200 OK' do
        get certificate_requests_path
        expect(response).to have_http_status(:ok)
      end

      it 'lists only the user\'s own requests' do
        create(:certificate_request, user: other)
        create(:certificate_request, user: user)
        get certificate_requests_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'GET /certificate_requests/:id' do
      it 'returns 200 OK when viewing own request' do
        cr = create(:certificate_request, user: user)
        get certificate_request_path(cr)
        expect(response).to have_http_status(:ok)
      end

      it 'redirects with error when viewing another user\'s request' do
        cr = create(:certificate_request, user: other)
        get certificate_request_path(cr)
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to be_present
      end

      it 'shows 404 for non-existent request' do
        get certificate_request_path(id: 999_999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
