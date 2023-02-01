# frozen_string_literal: true

class Platform::DeleteTelegramPosts
  prepend SimpleCommand

  attr_accessor :platform_posts

  def initialize(platform_posts)
    @platform_posts = platform_posts
  end

  def call
    @platform_posts.each do |platform_post|
      bot = Twilight::Application::CURRENT_TG_BOTS&.dig(platform_post.channel.token.to_s, :client)
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
