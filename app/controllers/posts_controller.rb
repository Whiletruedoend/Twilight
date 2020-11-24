class PostsController < ApplicationController
  def new
    @post = Post.new
  end

  def create
    @post = Post.new(posts_params)
    if !check_exist && @post.save
      redirect_to root_path
    else
      render :new
    end
  end
end