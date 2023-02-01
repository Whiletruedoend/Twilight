# frozen_string_literal: true

class Channel < ApplicationRecord
  belongs_to :platform
  belongs_to :user
  has_many :platform_posts

  has_one_attached :avatar

  def platform_posts_for_post(post)
    platform_posts.where(post: post)
  end

  def destroy
    avatar.purge
    super
  end
end
