# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def show
      @documents_count = Document.count
      @ready_count     = Document.ready.count
      @pending_count   = Document.pending.count + Document.processing.count
      @failed_count    = Document.failed.count
      @users_count     = User.count
    end
  end
end
