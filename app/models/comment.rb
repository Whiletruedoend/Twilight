# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user, optional: true # Site comment
  belongs_to :channel, optional: true # Optional if used linked channel
  belongs_to :platform_user, optional: true # Platform comment
  belongs_to :platform, optional: true
  has_many_attached :attachments do |attachable|
    attachable.variant :thumb100, resize_to_limit: [100, 100]
    attachable.variant :thumb150, resize_to_limit: [150, 150]
    attachable.variant :thumb200, resize_to_limit: [200, 200]
    attachable.variant :thumb250, resize_to_limit: [250, 250]
    attachable.variant :thumb300, resize_to_limit: [300, 300]
  end

  validate :text_or_attachments

  after_create :new_create_notification
  after_update :new_update_notification
  around_destroy :new_destroy_notification

  acts_as_tree order: 'created_at ASC'

  def text_or_attachments
    return unless text.empty? && !has_attachments

    errors.add(:not_found, 'Text and attachments cannot be empty!')
  end

  def username
    if platform_user.present?
      id = platform_user_id
      identifier = platform_user.identifier
      name = ''
      name += identifier['fname'] if identifier['fname'].present?
      name += identifier['lname'] if identifier['lname'].present?
      username = identifier[:username]
    else
      id = user.id
      name = user.name
      username = user.login
    end
    { id: id, name: name, username: username }
  end

  def destroy
    attachments.purge
    super
  end

  private

  def new_create_notification
    if self.platform_user_id.present? || (self.user_id.present? && (self.post.user_id != self.user_id))
      Notification.create!(item: self, user_id: self.post.user_id, event: "create", status: "success")
    end
  end

  def new_update_notification
    created_notification = self.post.user.notifications.where(item_type: self.class.name.to_s, event: "create").find{ |n| (n.item&.post_id.present? && (n.item.post_id == self.post_id)) && (n.item&.channel_id.nil? || (n.item&.channel_id.present? && (n.item.channel_id == self.channel_id))) }
    
    if created_notification.present? && ((Time.now - created_notification.created_at) > 15)
      if self.platform_user_id.present? || (self.user_id.present? && (self.post.user_id != self.user_id))
        Notification.create!(item: self, user_id: self.post.user_id, event: "update", status: "success")
      end
      if self.user_id.present? && (self.post.user_id != self.user_id)
        Notification.create!(item: self, user_id: self.user_id, event: "update", status: "warning")
      end
    end
  end

  def new_destroy_notification
    comment_user = self.user
    comment_user_id = self.user_id
    comment_platform_user = self.platform_user
    comment_platform_user_id = self.platform_user_id
    comment_post_user_id = self.post.user_id
    comment_user_name = self.username
    post_id = self.post_id
    yield
    if comment_platform_user_id.present? || (comment_user_id.present? && (comment_post_user_id != comment_user_id))
      name = comment_user_name[:name].present? ? comment_user_name[:name] : comment_user_name[:username]
      text = "#{post_id}@@#{name}"
      Notification.create!(item_type: self.class.name.to_s, user_id: comment_post_user_id, event: "delete", status: "success", text: text)
    end
    if comment_user_id.present? && (comment_post_user_id != comment_user_id)
      Notification.create!(item_type: self.class.name.to_s, user_id: comment_user_id, event: "delete", status: "warning", text: post_id)
    end
  end
end
