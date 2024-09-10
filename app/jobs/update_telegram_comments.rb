# frozen_string_literal: true

class UpdateTelegramComments < ApplicationJob
  queue_as :default

  def perform(tg_comments_ids, user_id, text)
    tg_comments = Comment.where(id: tg_comments_ids)
    user = User.find_by(id: user_id)
    Platform::UpdateTelegramComments.call(tg_comments, user, text)
  end
end
