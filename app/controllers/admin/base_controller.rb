# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :authorize_admin
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    private

    def authorize_admin
      raise Pundit::NotAuthorizedError unless current_user&.admin?
    end
  end
end
