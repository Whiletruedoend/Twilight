# frozen_string_literal: true

class DeletePostMessages
  prepend SimpleCommand

  attr_accessor :post, :channel_id

  def initialize(post, channel_id = nil)
    @post = post
    @channel_id = channel_id
  end

  def call
    if channel_id.nil?
      telegram_posts = post.platform_posts.joins(:platform).where(platforms: { title: 'telegram' })
      matrix_posts = post.platform_posts.joins(:platform).where(platforms: { title: 'matrix' })
      Platform::DeleteTelegramPosts.call(telegram_posts) if telegram_posts.any?
      Platform::DeleteMatrixPosts.call(matrix_posts) if matrix_posts.any?
      comment_ids = Comment.where(post: post).ids
      ActiveStorage::Attachment.where(record_type: 'Comment', record: comment_ids).destroy_all
      Comment.where(id: comment_ids).destroy_all
    else
      telegram_posts = post.platform_posts.joins(:platform).where(platforms: { title: 'telegram' },
                                                                  channel_id: channel_id)
      matrix_posts = post.platform_posts.joins(:platform).where(platforms: { title: 'matrix' }, channel_id: channel_id)
      title = Channel.find_by(id: channel_id).platform.title
      case title
      when 'telegram'
        Platform::DeleteTelegramPosts.call(telegram_posts) if telegram_posts.any?
      when 'matrix'
        Platform::DeleteMatrixPosts.call(matrix_posts) if matrix_posts.any?
      end
      platform = Platform.find_by(title: title)
      PlatformPost.where(platform: platform, post: post, channel_id: channel_id).destroy_all
      comment_ids = Comment.where(post: post, channel_id: channel_id).ids
      ActiveStorage::Attachment.where(record_type: 'Comment', record: comment_ids).destroy_all
      Comment.where(id: comment_ids).destroy_all
    end
    
    # Delete content without platform posts
    blog_platform = Platform.find_by(title: 'blog')
    content_nopp = @post.contents.includes(:platform_posts).where(platform_posts: {content_id: nil}).where.not(platform: blog_platform)
    content_nopp.destroy_all if content_nopp.any?
  end
end
