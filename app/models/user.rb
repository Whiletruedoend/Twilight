class User < ApplicationRecord
  has_many :posts
  validates :login, presence: true
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :rememberable, :validatable, :authentication_keys => [:login]

  before_create :generate_rss

  def generate_rss
    self.rss_token = SecureRandom.hex(16)
  end

  def will_save_change_to_email?
    false
  end

  def email_required?
    false
  end

  def email_changed?
    false
  end
end