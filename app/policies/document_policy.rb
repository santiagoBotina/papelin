# frozen_string_literal: true

class DocumentPolicy < ApplicationPolicy
  def index?   = true
  def show?    = user.admin? || record.ready?
  def create?  = user.admin?
  def update?  = user.admin?
  def destroy? = user.admin?

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.where(status: :ready)
    end
  end
end
