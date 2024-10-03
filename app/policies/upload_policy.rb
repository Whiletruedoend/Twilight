# frozen_string_literal: true

class UploadPolicy < ApplicationPolicy
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

  def show?
    allowed_to?(:privacy?, record) || user&.is_admin?
  end

  def destroy?
    (record.user == user) || user&.is_admin?
  end

  def rename?
    (record.user == user) || user&.is_admin?
  end
end