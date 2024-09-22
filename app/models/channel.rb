# frozen_string_literal: true

class Channel < ApplicationRecord
  belongs_to :platform
  belongs_to :user
  has_many :platform_posts
  has_many :comments

  has_one_attached :avatar

  scope :with_enabled_preload_room, -> { select { |ch| (ch.platform == Platform.find_by(title: "telegram")) && ch.options.dig("preload_attachments", "enabled") } }

  def platform_posts_for_post(post)
    platform_posts.where(post: post)
  end

  def destroy
    avatar.purge
    super
  end
end
