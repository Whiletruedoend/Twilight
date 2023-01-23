# frozen_string_literal: true

class Content < ApplicationRecord
  # validates :text, presence: true
  belongs_to :user
  belongs_to :post
  has_many_attached :attachments do |attachable|
    attachable.variant :thumb_100, resize_to_limit: [100, 100]
    attachable.variant :thumb_150, resize_to_limit: [150, 150]
    attachable.variant :thumb_200, resize_to_limit: [200, 200]
    attachable.variant :thumb_250, resize_to_limit: [250, 250]
    attachable.variant :thumb_300, resize_to_limit: [300, 300]
  end
end
