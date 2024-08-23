# frozen_string_literal: true

class Platform::DeleteMatrixPosts
  prepend SimpleCommand

  attr_accessor :platform_posts

  def initialize(platform_posts)
    @platform_posts = platform_posts
  end

  def call
    @platform_posts.each do |platform_post|
      matrix_token = platform_post.channel.token
      server = platform_post.channel.options['server']
      begin
        # Matrix onlylink is a Hash, but attachments is an Array.
        if platform_post.content.has_attachments? && !platform_post.identifier.is_a?(Hash)
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
        Rails.logger.error("Failed delete matrix messages at #{Time.now.utc.iso8601}".red)
      end
    end
  end
end
