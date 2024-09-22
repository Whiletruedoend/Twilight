# frozen_string_literal: true

class DeleteTelegramPosts < ApplicationJob
  queue_as :default

  def perform(telegram_posts_ids, user_id)
    telegram_posts = PlatformPost.where(id: telegram_posts_ids)
    user = User.find(user_id)
    Platform::DeleteTelegramPosts.call(telegram_posts, user)
  end
end
