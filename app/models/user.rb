class User < ApplicationRecord
  acts_as_easy_captcha
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :rememberable, :validatable, :authentication_keys => [:login]

  has_many :posts
  has_many :channels
  has_many :comments
  has_and_belongs_to_many :tags, class_name: 'Tag', join_table: "item_tags", :as => :item, foreign_key: "item_id", :dependent => :delete_all
  has_many :active_tags, -> { active("User") }, class_name: 'ItemTag', foreign_key: "item_id"

  validates :login, presence: true, uniqueness: true
  before_create :generate_rss

  def active_tags_names
    self.active_tags.map { |s| s.tag.name }
  end

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