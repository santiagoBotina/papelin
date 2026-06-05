# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Documents', type: :request do
  include ActiveJob::TestHelper

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

    it 'redirects to sign in for GET /admin/documents/:id/edit' do
      get edit_admin_document_path(document)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for PATCH /admin/documents/:id' do
      patch admin_document_path(document), params: { document: { title: 'New' } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for POST /admin/documents/:id/reingest' do
      post reingest_admin_document_path(document)
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

    it 'redirects with error for GET /admin/documents/:id/edit' do
      get edit_admin_document_path(document)
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'redirects with error for PATCH /admin/documents/:id' do
      patch admin_document_path(document), params: { document: { title: 'New' } }
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to be_present
    end

    it 'redirects with error for POST /admin/documents/:id/reingest' do
      post reingest_admin_document_path(document)
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

    describe 'GET /admin/documents/:id/edit' do
      it 'returns 200 OK' do
        get edit_admin_document_path(document)
        expect(response).to have_http_status(:ok)
      end

      it 'renders the edit form' do
        get edit_admin_document_path(document)
        expect(response.body).to include('Editar Documento')
        expect(response.body).to include('Actualizar Documento')
      end
    end

    describe 'PATCH /admin/documents/:id' do
      context 'with valid params (no file change)' do
        let(:update_params) do
          { document: { title: 'Updated Title', description: 'Updated desc' } }
        end

        it 'redirects to the document show page' do
          patch admin_document_path(document), params: update_params
          expect(response).to redirect_to(admin_document_path(document))
          expect(flash[:notice]).to eq('Documento actualizado.')
        end

        it 'updates the document title' do
          expect do
            patch admin_document_path(document), params: update_params
          end.to change { document.reload.title }.to('Updated Title')
        end

        it 'updates the document description' do
          expect do
            patch admin_document_path(document), params: update_params
          end.to change { document.reload.description }.to('Updated desc')
        end

        it 'does not enqueue an ingest job' do
          expect do
            patch admin_document_path(document),
                  params: { document: { title: 'Updated' } }
          end.not_to have_enqueued_job(Documents::IngestJob)
        end
      end

      context 'with a new file upload' do
        let(:file_params) do
          { file: fixture_file_upload('spec/fixtures/files/sample.txt', 'text/plain') }
        end
        let(:patch_with_file) do
          patch admin_document_path(document),
                params: { document: { title: 'With File', **file_params } }
        end

        it 'enqueues an ingest job' do
          expect { patch_with_file }.to have_enqueued_job(Documents::IngestJob).with(document.id)
        end

        it 'redirects with a notice' do
          patch_with_file
          expect(response).to redirect_to(admin_document_path(document))
          expect(flash[:notice]).to eq('Documento actualizado — reingesta en proceso.')
        end

        it 'resets the document status to pending' do
          expect { patch_with_file }.to change { document.reload.status }.to('pending')
        end

        it 'updates the document title' do
          expect { patch_with_file }.to change { document.reload.title }.to('With File')
        end

        it 'destroys existing chunks before re-ingesting' do
          create_list(:document_chunk, 3, document: document)

          expect do
            patch admin_document_path(document),
                  params: { document: { title: 'New File', **file_params } }
          end.to change { document.chunks.count }.from(3).to(0)
        end
      end

      context 'with invalid params' do
        it 'renders edit with unprocessable entity status' do
          patch admin_document_path(document),
                params: { document: { title: '' } }

          expect(response).to have_http_status(422)
        end
      end
    end

    describe 'POST /admin/documents/:id/reingest' do
      context 'when document is failed' do
        let(:failed_doc) { create(:document, :failed) }
        let(:reingest_request) { post reingest_admin_document_path(failed_doc) }

        it 'enqueues an ingest job for the failed document' do
          expect { reingest_request }.to have_enqueued_job(Documents::IngestJob).with(failed_doc.id)
        end

        it 'redirects with a notice' do
          reingest_request
          expect(response).to redirect_to(admin_document_path(failed_doc))
          expect(flash[:notice]).to eq('Reingesta iniciada.')
        end

        it 'resets the document to pending' do
          expect { reingest_request }.to change { failed_doc.reload.status }.to('pending')
        end

        it 'clears the processing error' do
          expect { reingest_request }.to change { failed_doc.reload.processing_error }.to(nil)
        end

        it 'destroys existing chunks' do
          create_list(:document_chunk, 2, document: failed_doc)

          expect do
            post reingest_admin_document_path(failed_doc)
          end.to change { failed_doc.chunks.count }.from(2).to(0)
        end
      end

      context 'when document is not failed' do
        it 'redirects with an alert' do
          post reingest_admin_document_path(document)

          expect(response).to redirect_to(admin_document_path(document))
          expect(flash[:alert]).to eq('Solo se pueden reingestar documentos fallidos.')
        end

        it 'does not enqueue an ingest job' do
          expect do
            post reingest_admin_document_path(document)
          end.not_to have_enqueued_job(Documents::IngestJob)
        end
      end
    end

    describe 'DELETE /admin/documents/:id' do
      it 'deletes the document' do
        doc = create(:document, :ready)
        expect do
          delete admin_document_path(doc)
        end.to change(Document, :count).by(-1)
      end

      it 'redirects with a notice' do
        doc = create(:document, :ready)
        delete admin_document_path(doc)
        expect(response).to redirect_to(admin_documents_path)
        expect(flash[:notice]).to eq('Documento eliminado.')
      end

      it 'calls purge_later on the attached file' do
        doc = create(:document, :ready)
        doc.file.attach(io: StringIO.new('fake content'), filename: 'test.txt', content_type: 'text/plain')
        # rubocop:disable RSpec/AnyInstance
        expect_any_instance_of(ActiveStorage::Attached::One).to receive(:purge_later).once
        # rubocop:enable RSpec/AnyInstance
        delete admin_document_path(doc)
      end

      it 'removes all associated chunks' do
        doc = create(:document, :ready)
        create_list(:document_chunk, 3, document: doc)

        expect do
          delete admin_document_path(doc)
        end.to change(DocumentChunk, :count).by(-3)
      end
    end
  end
end
