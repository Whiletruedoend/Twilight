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

  def edit
    @post = Post.find(params[:id])
    redirect_to @post if @post.user != current_user
  end

  def update
    @post = Post.find(params[:id])

    if @post.update(title: posts_params[:post][:title])
      params[:tags].each{ |tag| ItemTag.where(item: @post, tag_id: tag[0]).update(enabled: (tag[1].to_i)) } if params.has_key?(:tags)
      UpdatePostMessages.call(@post, params)
      redirect_to @post
    else
      render 'edit'
    end
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(title: posts_params[:post][:title])
    @post.user = current_user
    @post.save!
    if @post.save
      params[:tags].each{ |tag| ItemTag.create!(item: @post, tag_id: tag[0], enabled: (tag[1].to_i)) } if params.has_key?(:tags)
      SendPostToPlatforms.call(@post, params)
      redirect_to @post
    else
      render :new
    end
  end

  def rss
    user = current_user.present? ? current_user : (User.find_by_rss_token(params[:rss_token]) if params.has_key?(:rss_token))
    if user.present?
      item_posts = ItemTag.select { |item| (item.item_type == "Post") && (user.active_tags_names.include?(item.tag.name)) && (item.enabled == true) }
      item_posts.map!{ |item| item.item_id }.reject { |v| v.nil? }
      @posts = Post.where(id: item_posts).order(created_at: :desc)
    elsif Rails.configuration.credentials[:fail2ban][:enabled] && params.has_key?(:rss_token)
      ip = request.env['action_dispatch.remote_ip'] || request.env['REMOTE_ADDR']
      Rails.logger.error("Failed bypass token from #{ip} at #{Time.now.utc.iso8601}")
    end
  end

  def destroy
    @post = Post.find(params[:id])
    if @post.user == current_user
      DeletePostMessages.call(@post)
      ItemTag.where(item: @post).delete_all
      PlatformPost.where(post: @post).delete_all
      @post.get_content_attachments&.delete_all
      Content.where(post: @post).delete_all
      @post.delete
    end
    redirect_to posts_path
  end

  private
  def posts_params
    params.permit(:_method, :id, :authenticity_token, :commit, :platforms => {}, :deleted_attachments=> {}, :tags => {}, :attachments => [], :post => [:title, :content, :attachments])
  end
end