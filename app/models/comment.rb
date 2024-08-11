# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user, optional: true # Site comment
  belongs_to :channel, optional: true # Optional if used linked channel
  belongs_to :platform_user, optional: true # Platform comment
  belongs_to :platform, optional: true
  has_many_attached :attachments do |attachable|
    attachable.variant :thumb100, resize_to_limit: [100, 100]
    attachable.variant :thumb150, resize_to_limit: [150, 150]
    attachable.variant :thumb200, resize_to_limit: [200, 200]
    attachable.variant :thumb250, resize_to_limit: [250, 250]
    attachable.variant :thumb300, resize_to_limit: [300, 300]
  end

  validate :text_or_attachments

  acts_as_tree order: 'created_at ASC'

  def text_or_attachments
    return unless text.empty? && !has_attachments

    errors.add(:not_found, 'Text and attachments cannot be empty!')
  end

  def username
    if platform_user.present?
      identifier = platform_user.identifier
      name = ''
      name += identifier['fname'] if identifier['fname'].present?
      name += identifier['lname'] if identifier['lname'].present?
      username = identifier[:username]
    end
    { name: name.presence || '<No name>', username: username.presence || '' }
  end

  def destroy
    attachments.purge
    super
  end
end
