# frozen_string_literal: true

class PlatformPost < ApplicationRecord
  # validates :identifier, presence: true
  belongs_to :post
  belongs_to :content
  belongs_to :channel
  belongs_to :platform

  def post_link
    case platform.title
    when 'telegram'
      return "" if channel.nil?
      if channel.options.dig("username").present? #&& (chat['result']['type'] != 'private')
        "https://t.me/#{channel.options.dig("username")}/#{identifier['message_id']}"
      else
        ""
      end
    when 'matrix'
      return "" if channel.nil?
      event_id = identifier.is_a?(Hash) ? identifier["event_id"] : identifier[0]["event_id"]
      server = channel.options.dig("server")
      url = (server == "https://matrix.org/_matrix/") ? "https://app.element.io/#/room/#{channel.room}" : channel.options.dig("url")
      "#{url}/#{event_id}"
    end
  end
end
