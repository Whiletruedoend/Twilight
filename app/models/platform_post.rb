class PlatformPost < ApplicationRecord
  validates :identifier, presence: true
  belongs_to :content
  belongs_to :platform
  belongs_to :post
end