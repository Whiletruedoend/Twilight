# frozen_string_literal: true

class CommentsController < ApplicationController
  def create
    return redirect_to sign_in_path if current_user.nil? # No anonymous comments, sorry!

    current_post = Post.find(params[:comment][:post])
    authorize! current_post, to: :create_comments?

    current_comment = Comment.create!(text: params[:comment][:content], user: current_user, post: current_post)

    if current_comment.save
      redirect_to post_path(current_comment.post)
    else
      render :new
    end
  end

  def edit
    authorize! current_comment, to: :update?
  end

  def update
    authorize! current_comment

    if current_comment.update(text: params[:comment][:content], is_edited: true)
      redirect_to post_path(current_comment.post)
    else
      render :edit
    end
  end

  def destroy
    authorize! current_comment

    post = current_comment.post
    current_comment.delete
    redirect_to post_path(post)
  end
end
