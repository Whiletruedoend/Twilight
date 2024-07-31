# frozen_string_literal: true

module UsersHelper
  def display_name(user)
    if user&.name.present?
      user&.name
    else
      user&.login || 'Guest'
    end
  end
  
  def display_comments_name(user)
    return display_name(user) if user.is_a?(User)
    # PlatformUser
    username = user.identifier.dig("username")
    fname = user.identifier.dig("fname")
    lname = user.identifier.dig("lname")
    name = "#{fname} #{lname}"
    username.present? ? "#{name} (#{username})" : name
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
