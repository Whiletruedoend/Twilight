class Platform < ApplicationRecord
  validates :title, presence: true
  has_many :platform_posts
  has_many :platform_users
end