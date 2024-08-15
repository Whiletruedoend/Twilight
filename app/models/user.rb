# frozen_string_literal: true

class User < ApplicationRecord
  acts_as_easy_captcha
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :rememberable, :validatable, authentication_keys: [:login]

  has_many :posts, dependent: :destroy
  has_many :contents, dependent: :destroy
  has_many :channels, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :invite_codes, dependent: :delete_all
  has_many :categories, dependent: :delete_all
  has_and_belongs_to_many :tags, class_name: 'Tag', join_table: 'item_tags', as: :item
  has_many :active_tags, -> { active('User') }, class_name: 'ItemTag', foreign_key: 'item_id'
  has_many :visits, class_name: "Ahoy::Visit"

  has_one_attached :avatar

  validates :avatar, content_type: %r{\Aimage/.*\z}, size: { less_than: 10.megabytes, message: 'is not given between size' }
  validates :login, presence: true, uniqueness: true, length: { maximum: 256 }
  validates :name, allow_nil: true, length: { maximum: 64 }

  validate do |u|
    rss_default_posts = Rails.configuration.credentials[:rss_default_visible_posts]
    rss_posts_count = u.options['visible_posts_count'] || rss_default_posts.to_s
    max_rss_posts_count = Rails.configuration.credentials[:rss_max_visible_posts]
    if (rss_posts_count.to_i.to_s != rss_posts_count) ||
       (rss_posts_count.to_i > max_rss_posts_count || rss_posts_count.to_i <= 0)
      u.errors.add(:base,
                   'Bad RSS displayed posts count value!')
    end
    u.errors.add(:base, 'User with this display name already exists!') if name.present? && User.where(name: name).present?

    user_theme = u.options['theme']
    u.errors.add(:base, 'Bad Theme!') if user_theme.present? && Twilight::Application::THEMES.exclude?(user_theme)
  end

  before_create :generate_rss
  before_create :default_options

  def active_tags_names
    active_tags.map { |s| s.tag.name }
  end

  def generate_rss
    self.rss_token = SecureRandom.hex(16)
  end

  def default_options
    self.options = { visible_posts_count: Rails.configuration.credentials[:rss_default_visible_posts].to_s,
                     theme: 'default_theme' }
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

  # 'Disable' current password validation

  def update_with_password(params = {})
    if params.present? && params[:password].blank?
      params.delete(:encrypted_password)
      update_without_password(params)
    else
      verify_password_and_update(params)
    end
  end

  # https://github.com/plataformatec/devise/blob/master/lib/devise/models/database_authenticatable.rb
  def update_without_password(params = {})
    params.delete(:password)
    params.delete(:password_confirmation)
    result = update(params)
    clean_up_passwords
    result
  end

  def verify_password_and_update(params)
    encrypted_password = params.delete(:encrypted_password)

    if params[:password].blank?
      params.delete(:password)
      params.delete(:password_confirmation) if params[:password_confirmation].blank?
    end

    u = User.find_by(encrypted_password: encrypted_password)
    result =
      if u.present? && (params[:login] == u.login) # valid_password?(current_password)
        update(params)
      else
        assign_attributes(params)
        valid?
        errors.add(:current_password, encrypted_password.blank? ? :blank : :invalid)
        false
      end

    clean_up_passwords
    result
  end

  def displayed_name
    if name.present?
      name
    else
      login
    end
  end
  

  def destroy
    avatar.purge
    ItemTag.where(item_type: "User", item: self).delete_all
    ids = ItemTag.select { |i| i.item_type == "Post" && i.item.present? && i.item.user == self }
    ItemTag.where(id: ids).delete_all if ids.present?
    InviteCode.where(user: self).delete_all
    Comment.where(user: self).destroy_all
    Post.where(user: self).destroy_all
    Content.where(user: self).destroy_all
    Channel.where(user: self).destroy_all
    Category.where(user: self).destroy_all
    Ahoy::Event.where(user: self).update(user: nil)
    Ahoy::Visit.where(user: self).update(user: nil)
    self.delete
    #super # TODO: Fix it
  end
end
