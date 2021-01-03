class DeletePostMessages
  prepend SimpleCommand

  attr_accessor :post

  def initialize(post)
    @post = post
  end

  def call
    telegram_posts = post.platform_posts.joins(:platform).where(platforms: { title: "telegram"})
    matrix_posts = post.platform_posts.joins(:platform).where(platforms: { title: "matrix"})

    delete_telegram_posts(telegram_posts) if telegram_posts.any?
    delete_matrix_posts(matrix_posts) if matrix_posts.any?
  end

  def delete_telegram_posts(telegram_posts)
    telegram_posts.each do |platform_post|
      begin
        if platform_post.content.has_attachments?
          platform_post.identifier.each { |att| Telegram.bot.delete_message({ chat_id: att["chat_id"], message_id: att["message_id"] }) }
        else
          Telegram.bot.delete_message({ chat_id: platform_post[:identifier]["chat_id"], message_id: platform_post[:identifier]["message_id"] })
        end
      rescue # Message don't delete (if bot don't have access to message)
        Rails.logger.error("Failed delete telegram messages at #{Time.now.utc.iso8601}")
      end
    end
  end

  def delete_matrix_posts(matrix_posts)
    matrix_token = Rails.configuration.credentials[:matrix][:access_token]
    matrix_posts.each do |platform_post|
      begin
        if platform_post.content.has_attachments?
          platform_post.identifier.each do |att|
            method = "rooms/#{att["room_id"]}/redact/#{att["event_id"]}"
            data = { reason: "Delete post ##{platform_post.post_id}" }
            Matrix.post(matrix_token, method, data)
          end
        else
          method = "rooms/#{platform_post.identifier["room_id"]}/redact/#{platform_post.identifier["event_id"]}"
          data = { reason: "Delete post ##{platform_post.post_id}" }
          Matrix.post(matrix_token, method, data)
        end
      rescue
        Rails.logger.error("Failed delete matrix messages at #{Time.now.utc.iso8601}")
      end
    end
  end
end