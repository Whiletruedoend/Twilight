# frozen_string_literal: true

class DeleteMatrixPosts < ApplicationJob
  queue_as :default

  def perform(matrix_posts_ids, user_id)
    matrix_posts = PlatformPost.where(id: matrix_posts_ids)
    user = User.find(user_id)
    Platform::DeleteMatrixPosts.call(matrix_posts, user)
  end
end
