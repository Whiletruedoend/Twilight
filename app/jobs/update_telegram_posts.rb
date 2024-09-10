# frozen_string_literal: true

class UpdateTelegramPosts < ApplicationJob
  queue_as :default

  def perform(post_id, base_url, params, old_title)
    post = Post.find_by(id: post_id)
    Platform::UpdateTelegramPosts.call(post, base_url, params, old_title)
  end
end
