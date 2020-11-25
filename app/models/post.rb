class Post < ApplicationRecord
  validates :title, :content, presence: true
  belongs_to :user
  has_many :platform_posts
end