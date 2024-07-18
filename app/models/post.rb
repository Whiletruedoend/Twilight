# frozen_string_literal: true

class Post < ApplicationRecord
  # validates :title, presence: true
  belongs_to :user
  belongs_to :category, optional: true

  has_many :contents, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :platform_posts, dependent: :delete_all
  has_many :item_tags, class_name: 'ItemTag', foreign_key: 'item_id', dependent: :delete_all
  has_many :active_tags, -> { active('Post') }, class_name: 'ItemTag', foreign_key: 'item_id'

  before_create -> { self.uuid = SecureRandom.uuid }

  extend FriendlyId
  friendly_id :slug_candidates, use: [:slugged, :finders]

  # scope :with_active_tags, ->(tag_id) { select { |post| post.active_tags.include?(tag_id) } }
  scope :without_active_tags, -> { select { |post| post.active_tags.empty? } }

  #self.implicit_order_column = :created_at
  self.per_page = 15

  def self.get_posts(params, current_user)
    if params.key?(:user)
      current_privacy = current_user.present? ? [0, 1] : [0]
      privacy = (current_user.present? && (User.find_by(id: params[:user]) == current_user) ? [0, 1, 2] : current_privacy)
      posts = Post.where(privacy: privacy, user: User.find_by(id: params[:user]))
    else
      my_posts = current_user.present? ? Post.where(user: current_user).ids : []
      current_privacy = current_user.present? ? [0, 1] : [0]
      not_my_posts = Post.where.not(user: current_user).where(privacy: current_privacy).ids
      posts = Post.where(id: my_posts + not_my_posts)
    end
    posts = posts.where('lower(title) LIKE ?', "%#{params[:search].downcase}%") if params.key?(:search)
    posts
  end

  def published_platforms
    platform_posts.map { |p| { name: p.platform.title, url: p.post_link, channel_name: p.channel&.options&.dig("title") } }.group_by{ |g| g[:name] }
  end

  def active_tags_names
    active_tags.map { |s| s.tag.name }
  end

  def platforms
    platforms = {}
    Platform.all.find_each do |platform|
      platforms.merge!(platform.title => PlatformPost.where(platform_id: platform.id, post: self).any?)
    end
    platforms
  end

  def published_channels
    Channel.joins(:platform_posts).select('DISTINCT ON (channels.id) channels.*').where(platform_posts: { post: self })
  end

  def text
    text = ''
    contents.order(:id).each do |msg|
      text += msg[:text] if msg[:text].present?
    end
    text
  end

  def content_attachments
    Content.where(post: self).select { |c| c.attachments.any? }.map(&:attachments)[0]
  end

  def destroy
    DeletePostMessages.call(self)
    super
  end

  # Todo: make turbo for views?
  def views
    Ahoy::Event.where(name: "Post_#{self.id}").distinct.count(:visit_id)
  end

  def to_param
    uuid
  end

  def self.find(id)
    find_by! uuid: id
  end

  def self.find_with_slug(s)
    friendly.find_by(slug: s) || find(s)
  end

  def slug_url
    slug.present? ? slug : uuid
  end

  private

  def slug_candidates
    [:title, [:title, :uuid]]
  end
end
