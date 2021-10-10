# frozen_string_literal: true

require 'dry-initializer'

class PostsSearch < ApplicationSearch
  option :current_user
  # option :user_tags, optional: true
  option :limit, optional: true
  option :tag, optional: true
  option :title, optional: true

  def call(posts)
    @query = posts
    @query = reduce_by_privacy
    # @query = reduce_by_user_tags #if user_tags
    @query = reduce_by_tags if tag
    @query = reduce_by_title if title
    @query = reduce_by_limit if limit
    @query
  end

  private

  def reduce_by_tags
    @query.joins(:active_tags).where(active_tags: { tag_id: tag })
  end

  def reduce_by_privacy
    if current_user.present?
      @query.where('user_id=? OR privacy IN (0,1)', current_user.id)
    else
      @query.where('privacy=0')
    end
  end

  def reduce_by_title
    @query.where('title LIKE :like', like: "%#{title}%")
  end

  def reduce_by_limit
    @query.limit(limit.to_i)
  end
end
