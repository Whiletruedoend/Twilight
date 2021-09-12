# frozen_string_literal: true

class User < ApplicationRecord
  acts_as_easy_captcha
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :rememberable, :validatable, authentication_keys: [:login]

  has_many :posts
  has_many :channels
  has_many :comments
  has_many :invite_codes
  has_many :categories
  has_and_belongs_to_many :tags, class_name: 'Tag', join_table: 'item_tags', as: :item,
                                 dependent: :delete_all
  has_many :active_tags, -> { active('User') }, class_name: 'ItemTag', foreign_key: 'item_id'

  has_one_attached :avatar

  validates :login, presence: true, uniqueness: true

  validate do |u|
    rss_default_posts = Rails.configuration.credentials[:rss_default_visible_posts]
    rss_posts_count = u.options['visible_posts_count'] || rss_default_posts.to_s
    max_rss_posts_count = Rails.configuration.credentials[:rss_max_visible_posts]
    if (rss_posts_count.to_i.to_s != rss_posts_count) ||
       (rss_posts_count.to_i > max_rss_posts_count || rss_posts_count.to_i <= 0)
      u.errors.add(:base,
                   'Bad RSS displayed posts count value!')
    end
    # numericality: { only_integer: true, greater_than: 0 }
  end

  before_create :generate_rss

  def active_tags_names
    active_tags.map { |s| s.tag.name }
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
