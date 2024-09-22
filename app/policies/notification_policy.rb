# frozen_string_literal: true

class NotificationPolicy < ApplicationPolicy
  def view?
    record.user_id == user&.id
  end
end
