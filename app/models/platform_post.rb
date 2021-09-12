# frozen_string_literal: true

class PlatformPost < ApplicationRecord
  # validates :identifier, presence: true
  belongs_to :post
  belongs_to :content
  belongs_to :channel
  belongs_to :platform
end
