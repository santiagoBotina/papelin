# frozen_string_literal: true

module Admin
  class CertificateTypesController < BaseController
    before_action :set_certificate_type, only: %i[update]

    def index
      @certificate_types = CertificateType.ordered
    end

    def update
      @certificate_type.update!(active: params[:active] == 'true')
      redirect_to admin_certificate_types_path,
                  notice: "\"#{@certificate_type.label}\" #{@certificate_type.active? ? 'habilitado' : 'deshabilitado'}."
    end

    private

    def set_certificate_type
      @certificate_type = CertificateType.find(params[:id])
    end
  end
end
