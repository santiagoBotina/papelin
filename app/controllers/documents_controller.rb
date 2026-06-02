# frozen_string_literal: true

class DocumentsController < ApplicationController
  def index
    @documents = policy_scope(Document).recent
  end

  def show
    @document = Document.find(params[:id])
    authorize @document
  end

  def new
    @document = Document.new
    authorize @document
  end

  def create
    @document = current_user.documents.new(document_params)
    authorize @document

    if @document.save
      Documents::IngestJob.perform_later(@document.id)
      redirect_to documents_path, notice: 'Document uploaded and processing.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    @document = Document.find(params[:id])
    authorize @document
    @document.file.purge_later if @document.file.attached?
    @document.destroy!
    redirect_to documents_path, notice: 'Document deleted.'
  end

  private

  def document_params
    permitted = params.require(:document).permit(:title, :description, :doc_type, :cert_type, :file)
    permitted[:cert_type] = nil if permitted[:cert_type].blank?
    permitted
  end
end
