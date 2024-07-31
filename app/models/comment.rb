# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user, optional: true # Site comment
  belongs_to :channel, optional: true
  belongs_to :platform_user, optional: true # Platform comment
  has_many_attached :attachments

  validate :text_or_attachments

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
