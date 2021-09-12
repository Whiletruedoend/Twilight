# frozen_string_literal: true

class Content < ApplicationRecord
  # validates :text, presence: true
  belongs_to :user
  belongs_to :post
  has_many_attached :attachments
end
