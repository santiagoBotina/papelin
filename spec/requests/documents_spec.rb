# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documents', type: :request do
  let(:employee) { create(:user) }
  let(:admin)    { create(:user, :admin) }
  let(:document) { create(:document, :ready) }

  describe 'unauthenticated access' do
    it 'redirects to sign in for GET /documents' do
      get documents_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for GET /documents/:id' do
      get document_path(document)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for POST /documents' do
      post documents_path, params: { document: { title: 'Test', file: nil } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for DELETE /documents/:id' do
      delete document_path(document)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'authenticated as employee' do
    before { sign_in employee }

    describe 'GET /documents' do
      it 'returns 200 OK' do
        get documents_path
        expect(response).to have_http_status(:ok)
      end

      it 'scopes to ready documents' do
        create(:document, :ready)
        create(:document, :processing)
        get documents_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'GET /documents/:id' do
      it 'returns 200 OK for a ready document' do
        get document_path(document)
        expect(response).to have_http_status(:ok)
      end

      it 'redirects with error for a non-ready document' do
        pending_doc = create(:document, :pending)
        get document_path(pending_doc)
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe 'POST /documents' do
      it 'redirects with error (employees cannot create)' do
        post documents_path, params: { document: { title: 'Test', description: 'Test', doc_type: :policy } }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe 'DELETE /documents/:id' do
      it 'redirects with error (employees cannot destroy)' do
        delete document_path(document)
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to be_present
      end
    end
  end

  describe 'authenticated as admin' do
    before { sign_in admin }

    describe 'GET /documents' do
      it 'returns 200 OK' do
        get documents_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'GET /documents/:id' do
      it 'returns 200 OK' do
        get document_path(document)
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'GET /documents/new' do
      it 'returns 200 OK' do
        get new_document_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'POST /documents' do
      let(:upload_params) do
        {
          document: {
            title: 'Test Document',
            description: 'A test',
            doc_type: :policy,
            file: fixture_file_upload('spec/fixtures/files/sample.txt', 'text/plain')
          }
        }
      end

      it 'creates a new document' do
        expect { post documents_path, params: upload_params }.to change(Document, :count).by(1)
      end

      it 'sets the document title' do
        post documents_path, params: upload_params
        expect(Document.last.title).to eq('Test Document')
      end

      it 'redirects to documents list' do
        post documents_path, params: upload_params
        expect(response).to redirect_to(documents_path)
      end

      it 'enqueues Documents::IngestJob' do
        expect { post documents_path, params: upload_params }
          .to have_enqueued_job(Documents::IngestJob)
      end
    end

    describe 'DELETE /documents/:id' do
      it 'deletes the document and redirects' do
        doc = create(:document, :ready)
        expect do
          delete document_path(doc)
        end.to change(Document, :count).by(-1)

        expect(response).to redirect_to(documents_path)
      end
    end
  end
end
