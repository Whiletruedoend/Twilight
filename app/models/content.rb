# frozen_string_literal: true

class Content < ApplicationRecord
  # validates :text, presence: true
  belongs_to :user
  belongs_to :post
  belongs_to :platform

  has_many :platform_posts

  #before_validation :check_platform_presence, on: %i[craete update]

  after_create_commit do upd_post end
  after_update_commit do upd_post end
  after_destroy_commit do upd_post end

  def upd_post
    broadcast_update_to [self.post], partial: 'posts/post', locals: { post: self.post }, target: "post_#{self.post.id}"
  end

  #private

  #def check_platform_presence
  #  set_blog_platform if platform.nil?
  #end

  #def set_blog_platform
  #  self.platform = Platform.find_by(title: 'blog')
  #end
end
