# frozen_string_literal: true

class DeletePostMessages
  prepend SimpleCommand

  attr_accessor :post, :channel_id

  def initialize(post, channel_id = nil)
    @post = post
    @channel_id = channel_id
  end

  def call
    if channel_id.nil?
      telegram_posts = post.platform_posts.joins(:platform).where(platforms: { title: 'telegram' })
      matrix_posts = post.platform_posts.joins(:platform).where(platforms: { title: 'matrix' })
      delete_telegram_posts(telegram_posts) if telegram_posts.any?
      delete_matrix_posts(matrix_posts) if matrix_posts.any?
    else
      telegram_posts = post.platform_posts.joins(:platform).where(platforms: { title: 'telegram' },
                                                                  channel_id: channel_id)
      matrix_posts = post.platform_posts.joins(:platform).where(platforms: { title: 'matrix' }, channel_id: channel_id)
      title = Channel.find_by(id: channel_id).platform.title
      case title
      when 'telegram'
        delete_telegram_posts(telegram_posts) if telegram_posts.any?
      when 'matrix'
        delete_matrix_posts(matrix_posts) if matrix_posts.any?
      end
      platform = Platform.find_by(title: title)
      PlatformPost.where(platform: platform, post: post, channel_id: channel_id).delete_all
      comment_ids = Comment.where(post: post).ids # Сделать привязку коммента к платформ посту
      ActiveStorage::Attachment.where(record_type: 'Comment', record: comment_ids).delete_all
      Comment.where(post: post).delete_all
    end
  end

  def delete_telegram_posts(telegram_posts)
    telegram_posts.each do |platform_post|
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

  def delete_matrix_posts(matrix_posts)
    matrix_posts.each do |platform_post|
      matrix_token = platform_post.channel.token
      server = platform_post.channel.options['server']
      begin
        if platform_post.content.has_attachments?
          platform_post.identifier.each do |att|
            method = "rooms/#{att['room_id']}/redact/#{att['event_id']}"
            data = { reason: "Delete post ##{platform_post.post_id}" }
            Matrix.post(server, matrix_token, method, data)
          end
        else
          method = "rooms/#{platform_post.identifier['room_id']}/redact/#{platform_post.identifier['event_id']}"
          data = { reason: "Delete post ##{platform_post.post_id}" }
          Matrix.post(server, matrix_token, method, data)
        end
      rescue StandardError
        Rails.logger.error("Failed delete matrix messages at #{Time.now.utc.iso8601}")
      end
    end
  end
end
