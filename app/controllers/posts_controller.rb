class PostsController < ApplicationController

  before_action :authenticate_user!, except: :rss
  before_action :check_admin, except: :rss

  def check_admin
    redirect_to root_path unless current_user.is_admin
  end

  def index
    @post = params.has_key?(:user) ? Post.where(user: User.find_by_login(params[:user])).order(created_at: :desc) : Post.all.order(created_at: :desc)
  end

  def show
    @post = Post.find(params[:id])
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(posts_params[:post])
    @post.user = current_user
    @post.save!
    if @post.save
      params[:tags].each{ |tag| ItemTag.create!(item: @post, tag_id: tag[0], enabled: tag[1]) } if params.has_key?(:tags)
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
    params.permit(:authenticity_token, :commit, :tags => {}, :post => [:title, :content])
  end
end