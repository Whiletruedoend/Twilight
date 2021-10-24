# frozen_string_literal: true

class PostPolicy < ApplicationPolicy
  def privacy?
    false if nil?

    case record.privacy
    when 0
      true
    when 1
      user&.present?
    when 2
      record.user == user
    else
      false
    end
  end

  def export?
    allowed_to?(:privacy?, record) || user&.is_admin?
  end

  def show?
    allowed_to?(:privacy?, record) || user&.is_admin?
  end

  def update?
    (user&.id == record.user_id) || user&.is_admin?
  end

  def create?
    user&.is_admin?
  end

  def create_comments?
    allowed_to?(:privacy?, record) || record&.is_admin?
  end
end
