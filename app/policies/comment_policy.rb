# frozen_string_literal: true

class CommentPolicy < ApplicationPolicy
  def update?
    !record.identifier&.has_key?("is_deleted") && ((record.user == user) || user&.is_admin?)
  end

  def destroy?
    !record.identifier&.has_key?("is_deleted") && ((record.user == user) || user&.is_admin?)
  end

  def comment?
    user&.present? && !record.identifier&.has_key?("is_deleted")
  end
end
