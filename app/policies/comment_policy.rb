# frozen_string_literal: true

class CommentPolicy < ApplicationPolicy
  def update?
    (record.user == user) || user&.is_admin?
  end

  def destroy?
    (record.user == user) || user&.is_admin?
  end
end
