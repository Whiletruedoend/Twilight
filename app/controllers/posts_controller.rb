# frozen_string_literal: true

class PostsController < ApplicationController
  except_pages =
    if Rails.configuration.credentials[:need_auth]
      %i[rss show export raw]
    else
      %i[index feed rss show export raw]
    end

  before_action :authenticate_user!, except: except_pages
  after_action :track_action, only: %i[index show raw feed]

  def track_action
    post = Post.find_by(uuid: params.dig("uuid"))
    request_params = request.path_parameters
    if post.present?
      post_uuid = post.uuid.to_s
      if not Ahoy::Event.where(name: "Post_#{post_uuid}", visit_id: current_visit&.id).where_properties(uuid: post_uuid).exists?
        request_params["uuid"] = post_uuid
        ahoy.track("Post_#{post_uuid}", request_params)
      end
    else
      request_properties = { action: request_params[:action], controller: request_params[:controller] }
      if not Ahoy::Event.where(name: "Posts", visit_id: current_visit&.id).where_properties(request_properties).exists?
        ahoy.track("Posts", request_params)
      end
    end
  end

  def set_tags
    if params['action'].nil? || params['action'] == 'index'
      set_meta_tags(title: 'Posts',
                    description: 'Browse all posts',
                    keywords: 'Twilight, Notes, posts')
    elsif params['action'] == 'feed'                
      set_meta_tags(title: 'Feed',
        description: 'Twitter-style posts',
        keywords: 'Twilight, Notes, feed')
    elsif params['action'] == 'new'
      set_meta_tags(title: 'Create post',
                    description: 'Create your posts',
                    keywords: 'Twilight, Notes, posts')
    end
  end

  def set_tags_post(current_post)
    img_preview = current_post.attachments&.find{ |a| a.image? }
    img_preview_url = img_preview.present? ? "#{request.base_url}#{rails_blob_path(img_preview, only_path: true)}" : ""

    video_preview = current_post.attachments&.find{ |a| a.video? }
    video_preview_url = video_preview.present? ? "#{request.base_url}#{rails_blob_path(video_preview, only_path: true)}" : ""

    title = current_post.title.present? ? current_post.title : "#{current_post.uuid} | #{Rails.configuration.credentials[:title]}"
    category = current_post.category&.name || ""

    author = current_post.user.name.present? ? current_post.user.name : current_post.user.login

    if img_preview_url.present?
      set_meta_tags(og: {image: img_preview_url})
    end
    if video_preview_url.present? # Todo: add YouTube support 
      set_meta_tags(og: {video: video_preview_url})
    end

    set_meta_tags(title: title,
      description: current_post.text,
      keywords: current_post.active_tags.map { |t| t.tag.name }.join(", "),
      og: {
        title: title,
        description: current_post.text,
        type: "website",
        url: request.original_url
      },
      article: {
        published_time: current_post.created_at,
        modified_time: current_post.updated_at,
        section: category
      },
      author: author
    )
  end

  def index
    user_post = Post.get_posts(params, current_user)
    if user_post.present? && params.key?(:tags)
      ids = user_post.joins(:active_tags).where(active_tags: { tag_id: params[:tags] }).ids.uniq
      user_post = user_post.where(id: ids)
    elsif user_post.present? && params.key?(:category)
      user_post = user_post.where(category_id: params[:category])
    end
    @posts = user_post.order(created_at: :desc).paginate(page: params[:page])
  end

  def show
    authorize! current_post

    set_tags_post(current_post)
  end

  def edit
    authorize! current_post, to: :update?
  end

  def update
    authorize! current_post

    if current_post.update(privacy: posts_params[:post][:privacy] || 2)

      tags = (params[:tags].present? ? params[:tags].to_unsafe_h : {})

      if posts_params[:post][:new_tags_name].present?
        new_tags = posts_params[:post][:new_tags_name].split(',')
        new_tags.each do |tag|
          next if Tag.find_by(name: tag).present?

          enabled = !posts_params[:post][:new_tags_enabled_by_default].to_i == 0
          @tag = Tag.create!(name: tag, enabled_by_default: enabled)
          User.all.each { |usr| ItemTag.create!(item: usr, tag_id: @tag.id, enabled: enabled) }
          Post.all.each { |post| ItemTag.create!(item: post, tag_id: @tag.id, enabled: false) }
          tags.merge!({ "#{@tag.id}": '1' })
        end
      end

      tags.each { |tag| ItemTag.where(item: current_post, tag_id: tag[0]).update(enabled: tag[1].to_i) } if tags.any?

      if posts_params[:post][:category_name].present?
        cat = current_user.categories.find_by(name: posts_params[:post][:category_name])
        current_post.update(category: cat.presence || Category.create!(user: current_user,
                                                                       name: posts_params[:post][:category_name],
                                                                       color: posts_params[:post][:category_color]))
      # We need category owned by user checking?
      elsif posts_params[:post][:category_name].blank? && posts_params[:post][:category].present?
        if current_post.category_id != posts_params[:post][:category]
          current_post.update(category_id: posts_params[:post][:category])
        end
      elsif posts_params[:post][:category_name].empty? && posts_params[:post][:category].blank?
        current_post.update(category_id: nil) unless current_post.category_id.nil?
      end

      base_url = request.base_url

      channels_p = params['channels']&.to_unsafe_h
      published_channels_list = {}

      published_channels = current_post.published_channels.each{ |ch| published_channels_list.merge!("#{ch.id}" => "1") }
      
      new_channels_list = channels_p&.reject{|k,v| (v == "0") || (published_channels_list[k] == v) } || []
      deleted_channels_list = channels_p&.reject{ |k,v| (v == "1") || (published_channels_list[k] == v) } || []

      deleted_channels_list.each do |k, v|
        DeletePostMessages.call(current_post, current_user, k)
      end

      if new_channels_list.any?
        SendPostToPlatforms.call(current_post, base_url, params)
      end

      UpdatePostMessages.call(current_post, base_url, posts_params)
      current_post.update(title: posts_params[:post][:title], is_hidden: params[:post][:is_hidden])

      redirect_to current_post
    else
      render 'edit'
    end
  end

  def new
    authorize! current_user, to: :create_posts?

    @post = Post.new
    set_meta_tags(title: 'Posts',
                  description: 'Create & share your posts',
                  keywords: 'Twilight, Notes, posts')
  end

  def create
    authorize! current_user, to: :create_posts?

    @post = Post.new(title: posts_params[:post][:title], is_hidden: params[:post][:is_hidden])
    @post.user = current_user
    @post.privacy = posts_params.dig(:post, :privacy) || 2
    base_url = request.base_url

    if posts_params[:post][:category_name].present?
      cat = current_user.categories.find_by(name: posts_params[:post][:category_name])
      @post.category = (cat.presence || Category.create!(user: current_user,
                                                         name: posts_params[:post][:category_name],
                                                         color: posts_params[:post][:category_color]))
    elsif posts_params[:post][:category_name].blank? && posts_params[:post][:category].present?
      @post.category_id = posts_params[:post][:category]
    end

    new_tags = {}

    if posts_params[:post][:new_tags_name].present?
      tags = posts_params[:post][:new_tags_name].split(',')
      tags.each do |tag|
        next if Tag.find_by(name: tag).present?

        enabled = !posts_params[:post][:new_tags_enabled_by_default].to_i == 0
        @tag = Tag.create!(name: tag, enabled_by_default: enabled)
        User.all.each { |usr| ItemTag.create!(item: usr, tag_id: @tag.id, enabled: enabled) }
        Post.all.each { |post| ItemTag.create!(item: post, tag_id: @tag.id, enabled: false) }
        new_tags[@tag.id] = '1'
      end
    end

    @post.save!
    if @post.save
      tags = (posts_params[:tags].present? ? posts_params[:tags].to_unsafe_h : {})
      tags.merge!(new_tags) if new_tags.any?
      tags.each { |tag| ItemTag.create!(item: @post, tag_id: tag[0], enabled: tag[1].to_i) } if tags.any?

      SendPostToPlatforms.call(@post, base_url, posts_params)

      redirect_to post_path(@post)
    else
      render :new
    end
  end

  def rss
    user =
      if current_user.present?
        current_user
      else
        (User.find_by(rss_token: params[:token]) if params.key?(:token))
      end

    tags = user&.active_tags&.any? ? user&.active_tags&.map { |i| i.tag.id } : Tag.all.ids
    limit = user&.options&.dig('visible_posts_count') || Rails.configuration.credentials[:rss_default_visible_posts]
    @posts = PostsSearch.new(current_user: user, limit: limit, tags: tags, title: params[:title]).call(Post.all)

    @posts = @posts.order(created_at: (params[:sort] == 'asc' ? 'asc' : 'desc'))

    @markdown = Redcarpet::Markdown.new(CustomRender.new({ hard_wrap: true,
                                                           no_intra_emphasis: true,
                                                           fenced_code_blocks: true,
                                                           disable_indented_code_blocks: true,
                                                           tables: true,
                                                           underline: true,
                                                           highlight: true }), autolink: true)
  end

  def feed
    user =
      if current_user.present?
        current_user
      else
        (User.find_by(rss_token: params[:token]) if params.key?(:token))
      end

    @posts = PostsSearch.new( current_user: user,
                              uuid: params[:uuid],
                              user_id: params[:user],
                              strict_tags: params[:tag],
                              text: params[:text],
                              date: params[:to]
                            ).call(Post.all)

    @posts = @posts.paginate(page: params[:page], per_page: 15).order(created_at: (params[:sort] == 'asc' ? 'asc' : 'desc'))
    @last_date = nil

    if Rails.configuration.credentials[:fail2ban][:enabled] && user.nil? && params.key?(:token)
      ip = request.env['action_dispatch.remote_ip'] || request.env['REMOTE_ADDR']
      Rails.logger.error("Failed bypass token from #{ip} at #{Time.now.utc.iso8601}".red)
    end

    if params.dig("uuid").present?
      @current_post = @posts.find_by(uuid: params["uuid"])
      set_tags_post(@current_post) if @current_post.present?
    end

    respond_to do |format|
      format.html
      format.js
    end

    render 'posts/feed', layout: 'clear'
  end

  def export
    authorize! current_post, to: :export?

    FileUtils.rm_rf('tmp/export/') # clear old files

    file = ExportFiles.call(current_post).result

    send_file(file[:path], filename: file[:filename], type: file[:type])
  end

  def raw
    authorize! current_post, to: :show?

    set_meta_tags(title: current_post.title,
                  description: current_post.text,
                  keywords: current_post.active_tags.map { |t| t.tag.name }.join(", "),
                  og: {
                    title: current_post.title,
                    description: current_post.text,
                    type: "website",
                    url: request.original_url
                  })

    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                                                 disable_indented_code_blocks: true, autolink: false,
                                                                 tables: false, underline: false, highlight: false)
    render 'posts/raw', layout: 'clear'
  end

  def import
    authorize! current_user, to: :create_posts?

    return if params[:file].blank?

    post = ImportFiles.call(current_user, params[:file]).result
    if post.nil?
      redirect_to import_post_path
    else
      redirect_to post
    end
  end

  def destroy
    authorize! current_post, to: :update?

    current_post.destroy if current_post.user == current_user # other admin can't delete posts, lol
    redirect_to posts_path
  end

  private

  def posts_params
    params.permit(:_method,
                  :id,
                  :uuid,
                  :authenticity_token,
                  :commit,
                  channels: {},
                  options: {},
                  deleted_attachments: {}, tags: {}, attachments: [],
                  post: [:title,
                         :content,
                         :category,
                         :category_name,
                         :category_color,
                         :privacy,
                         :new_tags_name,
                         :new_tags_enabled_by_default,
                         :is_hidden,
                         :use_preload_room,
                         { attachments: [] }])
  end
end
