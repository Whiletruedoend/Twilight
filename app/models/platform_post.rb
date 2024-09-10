# frozen_string_literal: true

class PlatformPost < ApplicationRecord
  # validates :identifier, presence: true
  belongs_to :post
  belongs_to :content
  belongs_to :channel
  belongs_to :platform

  has_many :notifications, :as=>:item#, dependent: :destroy

  after_create :new_create_notification
  after_update :new_update_notification
  around_destroy :new_destroy_notification

  def post_link
    case platform.title
    when 'telegram'
      return "" if channel.nil?
      if channel.options.dig("username").present? #&& (chat['result']['type'] != 'private')
        "https://t.me/#{channel.options.dig("username")}/#{identifier['message_id']}"
      else
        ""
      end
    when 'matrix'
      return "" if channel.nil?
      event_id = identifier.is_a?(Hash) ? identifier["event_id"] : identifier[0]["event_id"]
      server = channel.options.dig("server")
      url = (server == "https://matrix.org/_matrix/") ? "https://app.element.io/#/room/#{channel.room}" : channel.options.dig("url")
      "#{url}/#{event_id}"
    end
  end

  private

  def new_create_notification
    notification = self.post.user.notifications.where(item_type: self.class.name.to_s, event: "create").find{ |n| (n.item&.post_id.present? && (n.item.post_id == self.post_id)) && (n.item&.channel_id.present? && (n.item.channel_id == self.channel_id)) }
    if !notification.present?
      Notification.create!(item: self, user_id: self.post.user.id, event: "create", status: "success")
    end
  end

  def new_update_notification
    created_notification = self.post.user.notifications.where(item_type: self.class.name.to_s, event: "create").find{ |n| (n.item&.post_id.present? && (n.item.post_id == self.post_id)) && (n.item&.channel_id.present? && (n.item.channel_id == self.channel_id)) }

    if created_notification.present? && ((Time.now - created_notification.created_at) > 15)
      notification = self.post.user.notifications.where(item_type: self.class.name.to_s, event: "update").find{ |n| (n.item&.post_id.present? && (n.item.post_id == self.post_id)) && (n.item&.channel_id.present? && (n.item.channel_id == self.channel_id)) }
      if !notification.present? || ((Time.now - notification.updated_at) > 15)
        Notification.create!(item: self, user_id: self.post.user.id, event: "update", status: "success")
      end
    end
  end

  def new_destroy_notification
    old_pp_post = self.post
    old_pp_user = old_pp_post.user_id
    old_pp_channel_id = self.channel_id
    title = self.channel.options.dig("title")
    yield
    notifications = old_pp_post.platform_posts.where(channel_id: old_pp_channel_id)
    if notifications.empty?
      Notification.create!(item_type: "PlatformPost", user_id: old_pp_user, event: "delete", status: "success", text: "#{title}" )
    end
  end

end
