class PostsController < ApplicationController

  before_action :authenticate_user!, except: :rss
  before_action :check_admin, except: :rss

  def check_admin
    redirect_to root_path unless current_user.is_admin
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(posts_params[:post])
    @post.user = current_user
    @post.save!
    if @post.save
      redirect_to root_path
    else
      render :new
    end
  end

  def rss
    @posts = Post.order(created_at: :desc) if current_user.present? || (params.has_key?(:rss_token) && User.find_by_rss_token(params[:rss_token].to_s).present?)
  end

  private
  def posts_params
    params.permit(:authenticity_token, :commit, :post => [:title, :content])
  end
end