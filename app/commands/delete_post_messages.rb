class DeletePostMessages
  prepend SimpleCommand

  attr_accessor :post, :platform_title

  def initialize(post, platform_title=nil)
    @post = post
    @platform_title = platform_title
  end

  def call
    telegram_posts = post.platform_posts.joins(:platform).where(platforms: { title: "telegram"})
    matrix_posts = post.platform_posts.joins(:platform).where(platforms: { title: "matrix"})

    if platform_title.nil?
      delete_telegram_posts(telegram_posts) if telegram_posts.any?
      delete_matrix_posts(matrix_posts) if matrix_posts.any?
    else
      case platform_title
        when "telegram"
          delete_telegram_posts(telegram_posts) if telegram_posts.any?
        when "matrix"
          delete_matrix_posts(matrix_posts) if matrix_posts.any?
      end
      platform = Platform.find_by_title(platform_title)
      PlatformPost.where(platform: platform, post: post).delete_all
      comment_ids = Comment.where(post: post).ids
      ActiveStorage::Attachment.where(record_type: "Comment", record: comment_ids).delete_all
      Comment.where(post: post).delete_all
    end
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