# frozen_string_literal: true

class UpdatePostMessages
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, params)
    @params = params
    @post = post

    @attachments = @params[:post][:attachments]
    @deleted_attachments = @params[:deleted_attachments]
  end

  def update_only_site_posts
    if @attachments.present?
      content = @post.contents.first # first content contains images
      @attachments.each { |image| content.attachments.attach(image) }
      content.update(has_attachments: true) unless content.has_attachments
    end
    if @deleted_attachments.present?
      @deleted_attachments.each do |attachment|
        if attachment[1] == '0'
          @post.content_attachments.find_by(blob_id: ActiveStorage::Blob.find_signed!(attachment[0]).id).purge
        end
      end
    end
    # fix if platform was deleted, but content still exist
    @post.contents.last(@post.contents.count - 1).each(&:delete) if @post.contents.count > 1
    @post.contents.update(text: params[:post][:content], has_attachments: @post.content_attachments.present?)
  end

  def call
    return update_only_site_posts if @post.platform_posts.empty?

    posted_platforms = @post.platforms

    Platform::UpdateTelegramPosts.call(@post, params) if posted_platforms['telegram']
    Platform::UpdateMatrixPosts.call(@post, params) if posted_platforms['matrix']
  end
end
