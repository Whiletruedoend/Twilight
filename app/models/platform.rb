class Platform < ApplicationRecord
  validates :title, presence: true
  has_many :platform_posts
end
