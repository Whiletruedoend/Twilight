class Notification < ApplicationRecord
  extend Enumerize
  belongs_to :item, polymorphic: true, optional: true
  belongs_to :user

  scope :unviewed, ->{ where(viewed: false) }
  default_scope { latest }

  enumerize :event, in: %w[none create update delete], default: :none, scope: :having_event
  enumerize :status, in: %w[info success warning error], default: :info, scope: :having_status
  validates :event, :status, presence: true

  after_create_commit do 
    broadcast_prepend_to "broadcast_to_user_#{self.user_id}", 
      target: :notifications
  end

  after_update_commit do 
    broadcast_update_to "broadcast_to_user_#{self.user_id}", 
      target: :notifications,
      partial: "notifications/notifications", 
      locals: { noti: Notification.unviewed.where(user_id: self.user_id) }
  end

  after_destroy_commit do 
    broadcast_update_to "broadcast_to_user_#{self.user_id}", 
      target: :notifications,
      partial: "notifications/notifications", 
      locals: { noti: Notification.unviewed.where(user_id: self.user_id) }
  end

  after_commit do
    broadcast_replace_to "broadcast_to_user_#{self.user_id}", 
      target: "notifications_count", 
      partial: "notifications/count", 
      locals: { count: self.user.unviewed_notifications_count }
    end
end
