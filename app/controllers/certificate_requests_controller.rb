# frozen_string_literal: true

class CertificateRequestsController < ApplicationController
  def index
    @certificate_requests = policy_scope(CertificateRequest).recent
  end

  def show
    @certificate_request = CertificateRequest.find(params[:id])
    authorize @certificate_request
  end
end
