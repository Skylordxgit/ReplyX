class CannedResponsePolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  def update?
    account_user.administrator? || scope.exists?(id: record.id)
  end

  def destroy?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.accessible_to(user, account_user)
    end
  end
end
