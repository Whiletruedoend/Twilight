# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def create_posts?
    record&.is_admin?
  end

  def create_channels?
    record&.is_admin?
  end

  def file_upload?
    user&.present?
  end

  def view_file_uploads?
    record&.is_admin?
  end
end
