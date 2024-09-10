# frozen_string_literal: true

class Platform::DeleteMatrixPosts
  prepend SimpleCommand

  attr_accessor :platform_posts, :user

  def initialize(platform_posts, user)
    @platform_posts = platform_posts
    @user = user
  end

  def call
    @platform_posts.each do |platform_post|
      matrix_token = platform_post.channel.token
      server = platform_post.channel.options['server']
      begin
        # Matrix onlylink is a Hash, but attachments is an Array.
        #if platform_post.content.has_attachments? && !platform_post.identifier.is_a?(Hash)
        if platform_post.identifier.is_a?(Array)
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
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed delete matrix messages at #{Time.now.utc.iso8601}".red)
    error_text = "Matrix (delete message: #{e.message})"
    Notification.create!(item_type: PlatformPost, user_id: user.id, event: "destroy", status: "error", text: error_text)
  end
end
