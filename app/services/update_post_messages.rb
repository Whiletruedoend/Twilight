# frozen_string_literal: true

class UpdatePostMessages
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, base_url, params)
    @params = params.to_unsafe_h
    @post = post
    @base_url = base_url

    @attachments = @params[:post][:attachments]
    @deleted_attachments = @params[:deleted_attachments]
  end

  def update_blog_posts
    platform = Platform.find_by(title: 'blog')
    att_content = @post.contents.find{ |c| c.platform == platform && c.has_attachments }

    if @attachments.present?
      if att_content.nil?
        att_content = Content.create!(user: @post.user, post: @post, text: nil,
                                      has_attachments: true, platform: platform)
      end
      @attachments.each { |image| @post.attachments.attach(image) }
      att_content.upd_post
    end

    if @deleted_attachments.present?
      @deleted_attachments.each do |attachment|
        if attachment[1] == '0'
          @post.attachments.find_by(blob_id: ActiveStorage::Blob.find_signed!(attachment[0]).id).purge
        end
      end
      att_content.upd_post
    end

    text_content = @post.contents.find{ |c| c.platform == platform && !c.has_attachments }
    if text_content.nil?
      Content.create!(user: @post.user, post: @post, text: params[:post][:content],
                      has_attachments: false, platform: platform)
    elsif text_content.present? && (text_content.text != params[:post][:content])
      text_content.update!(text: params[:post][:content])
    end
  end

  def call
    old_title = @post.title
    update_blog_posts
    return if @post.platform_posts.empty?

    posted_platforms = @post.platforms

    UpdateTelegramPosts.perform_later(@post.id, @base_url, params, old_title) if posted_platforms['telegram']
    UpdateMatrixPosts.perform_later(@post.id, @base_url, params) if posted_platforms['matrix']
  end
end
