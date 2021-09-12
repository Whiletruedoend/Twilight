# frozen_string_literal: true

class Platform < ApplicationRecord
  validates :title, presence: true
  has_many :platform_posts
  has_many :platform_users
  has_many :channels
end
