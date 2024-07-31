# frozen_string_literal: true

class CommentsController < ApplicationController
  def create
    return redirect_to sign_in_path if current_user.nil? # No anonymous comments, sorry!

    current_post = Post.find(params[:comment][:post])
    authorize! current_post, to: :create_comments?
    ref_url = request.referrer

    channels = params['channels']&.to_unsafe_h.select{ |k, v| v.to_i == 1 } if params['channels'].present?
    if params['channels'].present? && channels.any?
      SendCommentToPlatforms.call(params, channels, current_post, current_user)
    else
      current_comment = Comment.create!(text: params[:comment][:content], user: current_user, post: current_post, current_user: current_user)
    end
  end

  def edit
    authorize! current_comment, to: :update?
  end

  def update
    authorize! current_comment
    ref_url = request.referrer

    if current_comment.update(text: params[:comment][:content], is_edited: true, current_user: current_user)
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
    current_comment.delete
    if ref_url.include?("feed")
      redirect_to ref_url
    else
      redirect_to post_path(post)
    end
  end
end
