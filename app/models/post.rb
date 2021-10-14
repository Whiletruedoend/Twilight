# frozen_string_literal: true

class Post < ApplicationRecord
  # validates :title, presence: true
  belongs_to :user
  belongs_to :category, optional: true

  has_many :contents
  has_many :comments
  has_many :platform_posts
  has_many :item_tags, class_name: 'ItemTag', foreign_key: 'item_id'
  has_many :active_tags, -> { active('Post') }, class_name: 'ItemTag', foreign_key: 'item_id'

  # scope :with_active_tags, ->(tag_id) { select { |post| post.active_tags.include?(tag_id) } }
  scope :without_active_tags, -> { select { |post| post.active_tags.empty? } }

  self.per_page = 15

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

  def check_privacy(current_user)
    return false if nil?

    case privacy
    when 0
      true
    when 1
      current_user.present?
    when 2
      user == current_user
    else
      false
    end
  end

  def self.get_posts(params, current_user)
    if params.key?(:user)
      privacy = (current_user.present? && (User.find_by(login: params[:user]) == current_user) ? [0, 1, 2] : [0, 1])
      posts = Post.where(privacy: privacy, user: User.find_by(login: params[:user]))
    else
      my_posts = current_user.present? ? Post.where(user: current_user).ids : []
      not_my_posts = Post.where.not(user: current_user).where(privacy: [0, 1]).ids
      posts = Post.where(id: my_posts + not_my_posts)
    end
    posts = posts.where('lower(title) LIKE ?', "%#{params[:search].downcase}%") if params.key?(:search)
    posts
  end
end
