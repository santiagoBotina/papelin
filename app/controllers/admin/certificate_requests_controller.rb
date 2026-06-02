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
      case params[:update_action]
      when 'file_upload'
        handle_file_upload
      when 'status_update'
        handle_status_update
      else
        head :bad_request
      end
    end

    private

    def set_certificate_request
      @certificate_request = CertificateRequest.includes(:user).find(params[:id])
    end

    def handle_file_upload
      file = params.dig(:certificate_request, :generated_file)
      if file.blank?
        return redirect_to admin_certificate_request_path(@certificate_request),
                           alert: 'No se seleccion ningn archivo.'
      end

      @certificate_request.generated_file.purge if @certificate_request.generated_file.attached?
      @certificate_request.generated_file.attach(file)
      set_ready_if_marked

      redirect_to admin_certificate_request_path(@certificate_request),
                  notice: 'Archivo subido correctamente.'
    end

    def handle_status_update
      attrs = status_update_params
      assign_ready_at_on_status_change(attrs)

      if @certificate_request.update(attrs)
        redirect_to admin_certificate_request_path(@certificate_request),
                    notice: 'Estado actualizado.'
      else
        render :show, status: :unprocessable_content
      end
    end

    def set_ready_if_marked
      return unless params[:mark_ready] == 'true'

      @certificate_request.update!(status: :ready, ready_at: Date.current)
    end

    def assign_ready_at_on_status_change(attrs)
      return unless attrs[:status].to_s == 'ready' && @certificate_request.status != 'ready'

      attrs[:ready_at] = Date.current
    end

    def status_update_params
      params.require(:certificate_request)
            .permit(:status, :expected_ready_at, :admin_notes)
    end
  end
end
