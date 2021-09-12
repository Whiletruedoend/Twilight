# frozen_string_literal: true

class PlatformUser < ApplicationRecord
  belongs_to :platform
  has_many :comments

  has_one_attached :avatar
  has_many_attached :attachments
end
