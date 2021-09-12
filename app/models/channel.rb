# frozen_string_literal: true

class Channel < ApplicationRecord
  belongs_to :platform
  belongs_to :user
  has_many :platform_posts

  has_one_attached :avatar
end
