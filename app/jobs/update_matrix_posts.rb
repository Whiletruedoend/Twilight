# frozen_string_literal: true

class UpdateMatrixPosts < ApplicationJob
  queue_as :default

  def perform(post_id, base_url, params)
    post = Post.find_by(id: post_id)
    Platform::UpdateMatrixPosts.call(post, base_url, params)
  end
end
