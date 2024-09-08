module Notificable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, as: :item, dependent: :destroy
    after_create_commit :send_notifications_to_users
  end

  def send_notifications_to_users
    if self.respond_to? :user_ids
      self.user_ids&.each do |user_id|
        Notification.create user_id: user_id, item: self
      end
    end
  end
end
