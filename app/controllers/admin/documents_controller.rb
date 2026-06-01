# frozen_string_literal: true

module Admin
  class DocumentsController < BaseController
    def index
      @documents = Document.recent
    end

    def show
      @document = Document.find(params[:id])
    end

    def destroy
      @document = Document.find(params[:id])
      @document.destroy!
      redirect_to admin_documents_path, notice: 'Document deleted.'
    end
  end
end
