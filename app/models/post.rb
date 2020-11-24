class Post < ApplicationRecord
  validates :title, :text, :access, presence: true
  belongs_to :user
  has_many :platform_posts
end