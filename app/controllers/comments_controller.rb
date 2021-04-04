class CommentsController < ApplicationController

  def create
    return redirect_to sign_in_path if current_user.nil? # No anonymous comments, sorry!
    post = Post.find_by_id(params[:comment][:post])
    if post.present?
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404 unless post.check_privacy(current_user)
    else
      render file: "#{Rails.root}/public/404.html", layout: false, status: 404
    end

    @comment = Comment.create!(text: params[:comment][:content], user: current_user, post: post)

    if @comment.save
      redirect_to post_path(@comment.post)
    else
      render :new
    end
  end

  def edit
    @comment = Comment.find_by_id(params[:id])
    if @comment.present?
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404 if @comment.user != current_user
    else
      render file: "#{Rails.root}/public/404.html", layout: false, status: 404
    end
  end

  def update
    @comment = Comment.find_by_id(params[:id])
    if @comment.present?
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404 if @comment.user != current_user
    else
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404
    end

    if @comment.update(text: params[:comment][:content], is_edited: true)
      redirect_to post_path(@comment.post)
    else
      render :edit
    end
  end

  def destroy
    @comment = Comment.find_by_id(params[:id])
    if @comment.present?
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404 if ((@comment.user.nil? || current_user.nil?) || ((@comment.user != current_user) && !current_user.is_admin?))
    else
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404
    end
    post = @comment.post
    @comment.delete if (@comment.user == current_user) || ( current_user.present? && current_user.is_admin?)
    redirect_to post_path(post)
  end
end
