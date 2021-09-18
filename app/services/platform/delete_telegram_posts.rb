# frozen_string_literal: true

class Platform::DeleteTelegramPosts
  prepend SimpleCommand

  attr_accessor :platform_posts

  def initialize(platform_posts)
    @platform_posts = platform_posts
  end

  def call
    @platform_posts.each do |platform_post|
      bots_from_config = Telegram.bots_config.select { |_k, v| v == platform_post.channel.token }
      bots_hash = Telegram.bots.select { |k, _v| k == bots_from_config.first[0] }
      bot = bots_hash.first[1]
      if platform_post.content.has_attachments?
        platform_post.identifier.each do |att|
          bot.delete_message({ chat_id: att['chat_id'], message_id: att['message_id'] })
        end
      else
        bot.delete_message({ chat_id: platform_post[:identifier]['chat_id'],
                             message_id: platform_post[:identifier]['message_id'] })
      end
    rescue StandardError # Message don't delete (if bot don't have access to message)
      Rails.logger.error("Failed delete telegram messages at #{Time.now.utc.iso8601}")
    end
  end
end
