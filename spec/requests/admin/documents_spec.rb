# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Documents', type: :request do
  let(:employee) { create(:user) }
  let(:admin)    { create(:user, :admin) }
  let(:document) { create(:document, :ready) }

  describe 'unauthenticated access' do
    it 'redirects to sign in for GET /admin/documents' do
      get admin_documents_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for GET /admin/documents/:id' do
      get admin_document_path(document)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for DELETE /admin/documents/:id' do
      delete admin_document_path(document)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'authenticated as employee' do
    before { sign_in employee }

    it 'redirects with error for GET /admin/documents' do
      get admin_documents_path
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'redirects with error for GET /admin/documents/:id' do
      get admin_document_path(document)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'redirects with error for DELETE /admin/documents/:id' do
      delete admin_document_path(document)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end
  end

  describe 'authenticated as admin' do
    before { sign_in admin }

    describe 'GET /admin/documents' do
      it 'returns 200 OK' do
        get admin_documents_path
        expect(response).to have_http_status(:ok)
      end

      it 'includes all documents regardless of status' do
        create(:document, :pending)
        create(:document, :processing)
        create(:document, :ready)
        get admin_documents_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'GET /admin/documents/:id' do
      it 'returns 200 OK' do
        get admin_document_path(document)
        expect(response).to have_http_status(:ok)
      end

      it 'shows pending documents too' do
        pending_doc = create(:document, :pending)
        get admin_document_path(pending_doc)
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'DELETE /admin/documents/:id' do
      it 'deletes the document and redirects' do
        doc = create(:document, :ready)
        expect do
          delete admin_document_path(doc)
        end.to change(Document, :count).by(-1)

        expect(response).to redirect_to(admin_documents_path)
      end
    end
  end
end
