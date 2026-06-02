# frozen_string_literal: true

module Admin
  class DocumentsController < BaseController
    before_action :set_document, only: %i[show edit update destroy reingest]

    def index
      @documents = Document.recent
    end

    def show; end

    def edit; end

    def update
      if @document.update(document_params)
        if params[:document][:file].present?
          @document.chunks.destroy_all
          @document.update!(status: :pending)
          Documents::IngestJob.perform_later(@document.id)
          msg = 'Documento actualizado — reingesta en proceso.'
        else
          msg = 'Documento actualizado.'
        end
        redirect_to admin_document_path(@document), notice: msg
      else
        render :edit, status: :unprocessable_content
      end
    end

    def reingest
      unless @document.failed?
        return redirect_to(admin_document_path(@document),
                           alert: 'Solo se pueden reingestar documentos fallidos.')
      end

      @document.chunks.destroy_all
      @document.update!(status: :pending, processing_error: nil)
      Documents::IngestJob.perform_later(@document.id)
      redirect_to admin_document_path(@document), notice: 'Reingesta iniciada.'
    end

    def destroy
      @document.file.purge_later if @document.file.attached?
      @document.destroy!
      redirect_to admin_documents_path, notice: 'Documento eliminado.'
    end

    private

    def set_document
      @document = Document.find(params[:id])
    end

    def document_params
      permitted = params.require(:document).permit(:title, :description, :doc_type, :cert_type, :file)
      permitted[:cert_type] = nil if permitted[:cert_type].blank?
      permitted
    end
  end
end
