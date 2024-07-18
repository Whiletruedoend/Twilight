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
      # TODO: WTF?? Make local
      chat = Telegram.bot.get_chat(chat_id: identifier['chat_id'])
      if chat['result']['username'].present? && (chat['result']['type'] != 'private')
        "https://t.me/#{chat['result']['username']}/#{identifier['message_id']}"
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
