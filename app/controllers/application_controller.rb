# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!

  after_action :verify_authorized, unless: -> { devise_controller? || action_name == 'index' }
  after_action :verify_policy_scoped, unless: -> { devise_controller? || action_name != 'index' }

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  add_flash_types :info, :error

  private

  def user_not_authorized
    flash[:error] = 'You are not authorized to perform this action.'
    redirect_back_or_to(root_path)
  end

  def not_found
    render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
  end

  def after_sign_in_path_for(_resource)
    authenticated_root_path
  end
end
