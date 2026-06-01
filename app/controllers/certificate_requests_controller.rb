# frozen_string_literal: true

class CertificateRequestsController < ApplicationController
  def index
    @certificate_requests = policy_scope(CertificateRequest).recent
    render plain: 'placeholder'
  end

  def show
    @certificate_request = CertificateRequest.find(params[:id])
    authorize @certificate_request
    render plain: 'placeholder'
  end
end
