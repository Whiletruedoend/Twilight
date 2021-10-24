# frozen_string_literal: true

module UsersHelper
  def display_name(user)
    user&.name || user&.login || 'Guest'
  end
end
