# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, 'must be logged in' unless user

    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def new? = create?
  def create? = false
  def edit? = update?
  def update? = false
  def destroy? = false

  class Scope
    def initialize(user, scope)
      raise Pundit::NotAuthorizedError, 'must be logged in' unless user

      @user = user
      @scope = scope
    end

    def resolve = raise NotImplementedError, "#{self.class}#resolve has not been implemented"

    private

    attr_reader :user, :scope
  end
end
