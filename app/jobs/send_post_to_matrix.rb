# frozen_string_literal: true

class SendPostToMatrix < ApplicationJob
  queue_as :default

  def perform(post_id, base_url, params, channel_ids)
    post = Post.find_by(id: post_id)
    Platform::SendPostToMatrix.call(post, base_url, params, channel_ids)
  end
end
