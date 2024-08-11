# frozen_string_literal: true

class CommentsController < ApplicationController
  def new
    @comment = Comment.new(parent_id: params[:parent_id])
  end
  
  def create
    return redirect_to sign_in_path if current_user.nil? # No anonymous comments, sorry!

    current_post = Post.find(params[:post][:uuid])
    authorize! current_post, to: :create_comments?

    ref_url = request.referrer

    channels = params['channels']&.to_unsafe_h.select{ |k, v| v.to_i == 1 } if params['channels'].present?

    # Nested comments
    if params[:comment][:parent_id].to_i > 0
      parent = current_post.comments.find_by_id(params[:comment][:parent_id])
      @comment = parent.children.build(comment_params)
      if parent.channel.present?
        channels = {"#{parent.channel.id}" => "1"}
        SendCommentToPlatforms.call(params, channels, current_post, current_user)
      else
        @comment.parent = parent
        @comment.post = current_post
        @comment.user = current_user
        @comment.save!
      end
    else
      @comment = Comment.new(comment_params)

      if params['channels'].present? && channels.any?
        return set_flash_message :alert, "Not allowed!" unless allowed_to?(:create_platform_comments?, current_post)
        SendCommentToPlatforms.call(params, channels, current_post, current_user)
      else
        @comment.post = current_post
        @comment.user = current_user
        @comment.save!
      end

    end
  end

  def edit
    authorize! current_comment, to: :update?
  end

  def update
    authorize! current_comment
    ref_url = request.referrer

    if current_comment.update(text: params[:comment][:content], is_edited: true)
      if ref_url.include?("feed")
        redirect_to ref_url
      else
        redirect_to post_path(current_comment.post)
      end
    else
      render :edit
    end
  end

  def destroy
    authorize! current_comment
    ref_url = request.referrer
    
    # TODO: Delete from platforms
    post = current_comment.post

    DeletePlatformComments.call([current_comment])

    current_comment.destroy!

    redirect_to ref_url
  end

  private

  def comment_params
    params.require(:comment).permit(:text, :parent_id)
  end
end
