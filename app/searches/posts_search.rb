# frozen_string_literal: true

require 'dry-initializer'

class PostsSearch < ApplicationSearch
  option :current_user, optional: true
  # option :user_tags, optional: true
  option :id, optional: true
  option :user_id, optional: true
  option :limit, optional: true
  option :strict_tags, optional: true
  option :tags, optional: true
  option :title, optional: true
  option :text, optional: true
  option :date, optional: true

  def call(posts)
    @query = posts
    @query = reduce_by_privacy
    @query = reduce_by_id if id.present?
    @query = reduce_by_user if user_id.present?
    # @query = reduce_by_user_tags #if user_tags
    @query = reduce_by_strict_tags if strict_tags.present?
    @query = reduce_by_tags if tags
    @query = reduce_by_title if title
    @query = reduce_by_date if date.present?
    @query = reduce_by_title_or_text if text.present?
    # @query = reduce_by_text if text
    @query = reduce_by_limit if limit
    @query
  end

  private

  # Only posts for active tags, for Feed
  def reduce_by_strict_tags
    @query.joins(:active_tags).where(active_tags: { tag: strict_tags })
  end

  # Includes posts without any tags, for RSS
  def reduce_by_tags
    without_tags_ids = @query.without_active_tags.map(&:id)
    with_tags_ids = @query.joins(:active_tags).where(active_tags: { tag: tags }).ids
    @query.where(id: (without_tags_ids + with_tags_ids).uniq)
  end

  def reduce_by_privacy
    if current_user.present?
      # return @query if current_user.is_admin?
      @query.where('posts.user_id=? OR posts.privacy IN (0,1)', current_user.id)
    else
      @query.where('posts.privacy=0')
    end
  end

  def reduce_by_id
    @query.where('posts.id=?', id)
  end

  def reduce_by_user
    @query.where('posts.user_id=?', user_id)
  end

  def reduce_by_title
    @query.where('title LIKE :like', like: "%#{title}%")
  end

  def reduce_by_text
    @query.joins(:contents).where('contents.text LIKE :like', like: "%#{text}%")
  end

  def reduce_by_title_or_text
    @query.joins(:contents).where('(contents.text LIKE :like) OR (posts.title LIKE :like)', like: "%#{text}%")
  end

  def reduce_by_date
    @query.where('DATE(created_at) <= DATE(?)', (date&.to_date || Date.today))
  end

  def reduce_by_limit
    @query.limit(limit.to_i)
  end
end
