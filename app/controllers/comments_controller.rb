# frozen_string_literal: true

class CommentsController < ApplicationController
  def create
    return redirect_to sign_in_path if current_user.nil? # No anonymous comments, sorry!

    post = Post.find_by(id: params[:comment][:post])
    if post.present?
      unless post.check_privacy(current_user)
        return render file: "#{Rails.root}/public/404.html", layout: false,
                      status: :not_found
      end
    else
      render file: "#{Rails.root}/public/404.html", layout: false, status: :not_found
    end

    @comment = Comment.create!(text: params[:comment][:content], user: current_user, post: post)

    if @comment.save
      redirect_to post_path(@comment.post)
    else
      render :new
    end
  end

  def edit
    @comment = Comment.find_by(id: params[:id])
    if @comment.present?
      if @comment.user != current_user
        render file: "#{Rails.root}/public/404.html", layout: false,
               status: :not_found
      end
    else
      render file: "#{Rails.root}/public/404.html", layout: false, status: :not_found
    end
  end

  def update
    @comment = Comment.find_by(id: params[:id])
    if (@comment.present? && (@comment.user != current_user)) || @comment.blank?
      return render file: "#{Rails.root}/public/404.html", layout: false,
                    status: :not_found
    end

    if @comment.update(text: params[:comment][:content], is_edited: true)
      redirect_to post_path(@comment.post)
    else
      render :edit
    end
  end

  def destroy
    @comment = Comment.find_by(id: params[:id])
    if (@comment.present? &&
       ((@comment.user.nil? || current_user.nil?) ||
       ((@comment.user != current_user) && !current_user.is_admin?))) || @comment.blank?
      return render file: "#{Rails.root}/public/404.html", layout: false, status: :not_found
    end

    post = @comment.post
    @comment.delete if (@comment.user == current_user) || (current_user.present? && current_user.is_admin?)
    redirect_to post_path(post)
  end
end
