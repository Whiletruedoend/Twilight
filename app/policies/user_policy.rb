# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def create_posts?
    record&.is_admin?
  end

  def create_channels?
    record&.is_admin?
  end
end
