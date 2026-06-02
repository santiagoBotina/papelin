# frozen_string_literal: true

# Authorization for `CertificateRequest` records.
#
# Certificate requests are personal — each request belongs to a single user.
#
#   * Employees can file new requests (`create?`) and read their own
#     (`show?` / `index?` via the `Scope`). Status transitions are an
#     HR/Admin concern, so employees are forbidden from `update?` and
#     `destroy?` — even on their own requests.
#
#   * Admins can read every request (for support and audit), file new ones
#     (operational filing on behalf of a user is allowed), and update
#     status (`update?` returns true). `destroy?` returns false for
#     everyone — the records are permanent for compliance reasons.
class CertificateRequestPolicy < ApplicationPolicy
  def index? = true
  def show? = owner_or_admin?
  def new? = !user.admin?
  def create? = !user.admin?
  def update? = user.admin?
  def destroy? = false

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
