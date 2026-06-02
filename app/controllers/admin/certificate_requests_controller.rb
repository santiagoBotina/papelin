# frozen_string_literal: true

module Admin
  class CertificateRequestsController < BaseController
    before_action :set_certificate_request, only: %i[show update]

    def index
      @user = User.find(params[:user_id]) if params[:user_id]
      scope = @user ? @user.certificate_requests : CertificateRequest
      @certificate_requests = scope.includes(:user).recent
    end

    def show; end

    def update
      if params.dig(:certificate_request, :generated_file).present?
        @certificate_request.generated_file.attach(params[:certificate_request][:generated_file])
      end

      status = params.dig(:certificate_request, :status)
      @certificate_request.assign_attributes(status: status) if status.present?

      if @certificate_request.save
        redirect_to admin_certificate_request_path(@certificate_request), notice: 'Certificado actualizado.'
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    def set_certificate_request
      @certificate_request = CertificateRequest.includes(:user).find(params[:id])
    end
  end
end
