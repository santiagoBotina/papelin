# frozen_string_literal: true

module Admin
  class CertificateTypesController < BaseController
    before_action :set_certificate_type, only: %i[edit update destroy]

    def index
      @certificate_types = CertificateType.ordered
    end

    def new
      @certificate_type = CertificateType.new
    end

    def edit; end

    def create
      @certificate_type = CertificateType.new(certificate_type_params)
      if @certificate_type.save
        redirect_to admin_certificate_types_path, notice: "Tipo \"#{@certificate_type.label}\" creado."
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @certificate_type.update(certificate_type_params)
        redirect_to admin_certificate_types_path, notice: "Tipo \"#{@certificate_type.label}\" actualizado."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @certificate_type.associated_requests?
        redirect_to admin_certificate_types_path,
                    alert: 'No se puede eliminar — hay solicitudes asociadas a este tipo.'
      else
        @certificate_type.destroy!
        redirect_to admin_certificate_types_path, notice: 'Tipo eliminado.'
      end
    end

    private

    def set_certificate_type
      @certificate_type = CertificateType.find(params[:id])
    end

    def certificate_type_params
      if action_name == 'create'
        params.require(:certificate_type).permit(:key, :label, :description, :active)
      else
        params.require(:certificate_type).permit(:label, :description, :active)
      end
    end
  end
end
