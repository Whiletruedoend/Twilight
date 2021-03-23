class PostsController < ApplicationController

  before_action :authenticate_user!, except: [:rss, :show]
  before_action :check_admin, except: [:rss, :index, :show]

  def check_admin
    redirect_to root_path unless current_user.is_admin
  end

  def index
    user_post = if params.has_key?(:user)
                  privacy = (current_user.present? && (User.find_by_login(params[:user]) == current_user) ? [0,1,2] : [0,1])
                  Post.where(privacy: privacy, user: User.find_by_login(params[:user]))
                else
                  my_posts =  current_user.present? ? Post.where(user: current_user).ids : []
                  not_my_posts = Post.where.not(user: current_user).where(privacy: [0,1]).ids
                  Post.where(id: my_posts+not_my_posts)
                end
    if user_post.present? && params.has_key?(:tags)
      ids = user_post.joins(:active_tags).where(active_tags: {tag_id: params[:tags]}).ids.uniq
      user_post = user_post.where(id: ids)
    end
    @post = user_post.order(created_at: :desc).paginate(page: params[:page])
  end

  def show
    @post = Post.find_by_id(params[:id])
    if @post.present?
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404 unless @post.check_privacy(current_user)
    else
      render file: "#{Rails.root}/public/404.html", layout: false, status: 404
    end
  end

  def edit
    @post = Post.find_by_id(params[:id])
    if @post.present?
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404 unless @post.check_privacy(current_user)
    else
      render file: "#{Rails.root}/public/404.html", layout: false, status: 404
    end
  end

  def update
    @post = Post.find_by_id(params[:id])
    if @post.present?
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404 unless @post.check_privacy(current_user)
    else
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404
    end
    if @post.update(title: posts_params[:post][:title], privacy: (posts_params[:post][:privacy] || 2))
      params[:tags].each{ |tag| ItemTag.where(item: @post, tag_id: tag[0]).update(enabled: (tag[1].to_i)) } if params.has_key?(:tags)

      channels_p = params["channels"]&.to_unsafe_h
      if channels_p.present?
        channels_p.each do |k,v|
          if !v.to_i.zero? # TODO: make it? Need2fix duplicate content when creating!
            #params["platforms"] = { k=>(v ? 1 : 0).to_s }
            #SendPostToPlatforms.call(@post, params)
          else
            DeletePostMessages.call(@post, k)
          end
        end
      end

      UpdatePostMessages.call(@post, params) # TODO: optimize it?

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
    @post.privacy = posts_params.dig(:post, :privacy) || 2
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
    my_posts =  current_user.present? ? Post.where(user: current_user).ids : []
    not_my_posts = Post.where.not(user: current_user).where(privacy: [0,1]).ids
    all_posts = my_posts + not_my_posts
    if user.present?
      item_posts = ItemTag.select { |item| (item.item_type == "Post") && (user.active_tags_names.include?(item.tag.name)) && (item.enabled == true) }
      item_posts.map!{ |item| item.item_id }.reject { |v| v.nil? }
      if item_posts.any?
        @posts = Post.where(id: all_posts.reject{ |post| item_posts.exclude?(post) }).order(created_at: :desc)
      else
        @posts = Post.where(id: all_posts).order(created_at: :desc)
      end
    elsif Rails.configuration.credentials[:fail2ban][:enabled] && params.has_key?(:rss_token)
      ip = request.env['action_dispatch.remote_ip'] || request.env['REMOTE_ADDR']
      Rails.logger.error("Failed bypass token from #{ip} at #{Time.now.utc.iso8601}")
    end
  end

  def destroy
    @post = Post.find_by_id(params[:id])
    if @post.present?
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404 unless @post.check_privacy(current_user)
    else
      return render file: "#{Rails.root}/public/404.html", layout: false, status: 404
    end
    if @post.user == current_user
      DeletePostMessages.call(@post)
      ItemTag.where(item: @post).delete_all
      PlatformPost.where(post: @post).delete_all
      comment_ids = Comment.where(post: @post).ids
      ActiveStorage::Attachment.where(record_type: "Comment", record: comment_ids).delete_all
      Comment.where(post: @post).delete_all
      @post.get_content_attachments&.delete_all
      Content.where(post: @post).delete_all
      @post.delete
    end
    redirect_to posts_path
  end

  private
  def posts_params
    params.permit(:_method, :id, :authenticity_token, :commit, :channels => {}, :deleted_attachments=> {}, :tags => {}, :attachments => [], :post => [:title, :content, :attachments, :privacy])
  end
end