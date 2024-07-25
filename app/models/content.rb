# frozen_string_literal: true

class Content < ApplicationRecord
  # validates :text, presence: true
  belongs_to :user
  belongs_to :post

  # TODO: Если было изменено содержимое контента, то оно не всегда почему-то хочет отображать изменения.
  after_create_commit do upd_post end
  after_update_commit do upd_post end
  after_destroy_commit do upd_post end

  has_many_attached :attachments do |attachable|
    attachable.variant :thumb100, resize_to_limit: [100, 100]
    attachable.variant :thumb150, resize_to_limit: [150, 150]
    attachable.variant :thumb200, resize_to_limit: [200, 200]
    attachable.variant :thumb250, resize_to_limit: [250, 250]
    attachable.variant :thumb300, resize_to_limit: [300, 300]
  end

  def destroy
    attachments.purge
    super
  end

  def upd_post
    broadcast_update_to [self.post], partial: 'posts/post', locals: { post: self.post }, target: "post_#{self.post.id}"
  end
end
