# frozen_string_literal: true

class CertificateRequestsController < ApplicationController
  def index
    if current_user.admin?
      skip_policy_scope
      return redirect_to admin_certificate_requests_path
    end

    @certificate_requests = policy_scope(CertificateRequest).recent
  end

  def show
    @certificate_request = CertificateRequest.find(params[:id])
    authorize @certificate_request
  end

  def new
    @certificate_request = CertificateRequest.new
    authorize @certificate_request
    @available_cert_types = CertificateRequest.available_cert_types
    @conversation_id = params[:conversation_id]
  end

  def create
    @available_cert_types = CertificateRequest.available_cert_types
    @certificate_request = current_user.certificate_requests.new(cert_request_params)
    authorize @certificate_request

    unless @available_cert_types.include?(@certificate_request.cert_type)
      @certificate_request.errors.add(:cert_type, :unavailable,
                                      message: 'no está disponible en este momento')
      return render :new, status: :unprocessable_content
    end

    if @certificate_request.save
      redirect_to redirect_path_after_create,
                  notice: "Solicitud #{@certificate_request.reference_number} creada exitosamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def cert_request_params
    params.require(:certificate_request)
          .permit(:cert_type, :notes)
          .merge(requested_at: Date.current)
  end

  def redirect_path_after_create
    conversation_id = params.dig(:certificate_request, :conversation_id)
    return conversation_path(conversation_id) if conversation_id.present?

    certificate_request_path(@certificate_request)
  end
end
