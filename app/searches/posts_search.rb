# frozen_string_literal: true

require 'dry-initializer'

class PostsSearch < ApplicationSearch
  option :current_user
  # option :user_tags, optional: true
  option :limit, optional: true
  option :tags, optional: true
  option :title, optional: true
  option :text, optional: true
  option :date, optional: true

  def call(posts)
    @query = posts
    @query = reduce_by_privacy
    # @query = reduce_by_user_tags #if user_tags
    @query = reduce_by_tags if tags
    @query = reduce_by_title if title
    @query = reduce_by_date if date
    @query = reduce_by_title_or_text if text
    #@query = reduce_by_text if text
    @query = reduce_by_limit if limit
    @query
  end

  private

  def reduce_by_tags
    without_tags_ids = @query.without_active_tags.map{ |p| p.id }
    with_tags_ids = @query.joins(:active_tags).where(active_tags: { tag: tags })
    @query.where(id: (without_tags_ids+with_tags_ids).uniq)
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

  def reduce_by_text
    @query.joins(:contents).where('contents.text LIKE :like', like: "%#{text}%")
  end

  def reduce_by_title_or_text
    @query.joins(:contents).where('contents.text LIKE :like OR title LIKE :like', like: "%#{text}%")
  end

  def reduce_by_date
    @query.where("DATE(created_at) <= DATE(?)", (date&.to_date || Date.today))
  end

  def reduce_by_limit
    @query.limit(limit.to_i)
  end
end
