# frozen_string_literal: true

class UpdateMatrixComments < ApplicationJob
  queue_as :default

  def perform(mx_comments_ids, user_id, text)
    mx_comments = Comment.where(id: mx_comments_ids)
    user = User.find_by(id: user_id)
    Platform::UpdateMatrixComments.call(mx_comments, user, text)
  end
end
# Not used