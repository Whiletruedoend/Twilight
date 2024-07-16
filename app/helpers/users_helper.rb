# frozen_string_literal: true

module UsersHelper
  def display_name(user)
    if user&.name.present?
      user&.name
    else
      user&.login || 'Guest'
    end
  end
  def channel_url(channel)
    if channel.platform.title == "telegram" && channel.options&.dig("username").present?
      link_to(channel.platform.title.capitalize, "https://t.me/#{channel.options&.dig("username")}", target: '_blank' )
    elsif channel.platform.title == "matrix" && channel.options&.dig("url").present?
      link_to(channel.platform.title.capitalize, channel.options&.dig("url"), target: '_blank')
    else
      channel.platform.title.capitalize
    end
  end
end
