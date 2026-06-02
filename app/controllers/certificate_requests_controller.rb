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
end
