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

  # scope :with_active_tags, ->(tag_id) { select { |post| post.active_tags.include?(tag_id) } }
  scope :without_active_tags, -> { select { |post| post.active_tags.empty? } }

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
end
