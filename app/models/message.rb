class Message < ApplicationRecord
  validates :text, presence: true
  belongs_to :user
  belongs_to :post
  #has_many :attachments
end