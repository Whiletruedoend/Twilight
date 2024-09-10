# frozen_string_literal: true

class UpdatePlatformComments
  prepend SimpleCommand

  attr_accessor :comments, :current_user, :params

  def initialize(comments, current_user, params)
    @params = params.to_unsafe_h
    @text = @params[:comment][:content]
    @comments = comments
    @current_user = current_user
  end

  def call
    blog_platform = Platform.find_by(title: 'blog')
    @comments.where("platform_id=? or platform_id is NULL", blog_platform.id).update!(text: @text, is_edited: true)

    tg_platform = Platform.find_by(title: 'telegram')
    matrix = Platform.find_by(title: 'matrix')

    if tg_platform.present?
      tg_comments = @comments.where(platform: tg_platform)
      UpdateTelegramComments.perform_later(tg_comments.ids, @current_user.id, @text) if tg_comments.any?
    end
    if matrix.present?
      mx_comments = @comments.where(platform: matrix)
      UpdateMatrixComments.perform_later(tg_comments.ids, @current_user.id, @text) if mx_comments.any?
    end
  end
end
