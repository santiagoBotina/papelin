# frozen_string_literal: true

# Authorization for `Conversation` records.
#
# A conversation is a private chat session between a single employee and the
# assistant. The owner has full read/write/delete rights. Admins inherit those
# rights for operational reasons (support escalations, audit, data takedowns).
#
# `index?` always returns true because the controller uses `policy_scope` to
# narrow the result set per role — denying the action entirely would just
# produce an empty page.
class ConversationPolicy < ApplicationPolicy
  def index? = true
  def show? = owner_or_admin?
  def create? = true
  def update? = owner_or_admin?
  def destroy? = owner_or_admin?

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.where(user: user)
    end
  end

  private

  def owner_or_admin?
    return true if user.admin?

    record.user_id == user.id
  end
end
