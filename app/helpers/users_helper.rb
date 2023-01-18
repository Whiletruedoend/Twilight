# frozen_string_literal: true

module UsersHelper
  def display_name(user)
    if user&.name.present?
      user&.name
    else
      user&.login || 'Guest'
    end
  end
end
