# frozen_string_literal: true

class Platform::DeleteTelegramPosts
  prepend SimpleCommand

  attr_accessor :platform_posts, :user

  def initialize(platform_posts, user)
    @platform_posts = platform_posts
    @user = user
  end

  def call
    @platform_posts.each do |platform_post|
      bot = Twilight::Application::CURRENT_TG_BOTS&.dig(platform_post.channel.token.to_s, :client)
      if platform_post.identifier.is_a?(Array)
        platform_post.identifier.each do |att|
          bot.delete_message({ chat_id: att['chat_id'], message_id: att['message_id'] })
        end
      else
        bot.delete_message({ chat_id: platform_post[:identifier]['chat_id'],
                             message_id: platform_post[:identifier]['message_id'] })
      end
    end
  rescue StandardError => e # Message don't delete (if bot don't have access to message)
    Rails.logger.error("Failed delete telegram messages at #{Time.now.utc.iso8601}: #{e.message}".red)
    error_text = "Telegram (delete message: #{e.message})"
    Notification.create!(item_type: "PlatformPost", user_id: user.id, event: "destroy", status: "error", text: error_text)
  end
end
