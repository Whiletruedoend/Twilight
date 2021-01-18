class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user, required: false # Site comment
  belongs_to :platform_user, required: false # Platform comment
  has_many_attached :attachments

  def get_username
    if self.platform_user.present?
      identifier = self.platform_user.identifier
      name = ""
      name += identifier["fname"] if identifier["fname"].present?
      name += identifier["lname"] if identifier["lname"].present?
      username = identifier[:username]
    end
    { name: name.present? ? name : "<No name>", username: username.present? ? username : ""}
  end
end