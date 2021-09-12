# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user, optional: true # Site comment
  belongs_to :platform_user, optional: true # Platform comment
  has_many_attached :attachments

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
end
