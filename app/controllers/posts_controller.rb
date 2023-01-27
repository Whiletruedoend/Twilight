# frozen_string_literal: true

class PostsController < ApplicationController
  except_pages =
    if Rails.configuration.credentials[:need_auth]
      %i[rss show export raw]
    else
      %i[index feed rss show export raw]
    end

  before_action :authenticate_user!, except: except_pages

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
  end

  def edit
    authorize! current_post, to: :update?
  end

  def update
    authorize! current_post

    if current_post.update(privacy: (posts_params[:post][:privacy] || 2))

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
        current_post.update(category: (cat.presence || Category.create!(user: current_user,
                                                                        name: posts_params[:post][:category_name],
                                                                        color: posts_params[:post][:category_color])))
      # We need category owned by user checking?
      elsif posts_params[:post][:category_name].blank? && posts_params[:post][:category].present?
        if current_post.category_id != posts_params[:post][:category]
          current_post.update(category_id: posts_params[:post][:category])
        end
      elsif posts_params[:post][:category_name].empty? && posts_params[:post][:category].blank?
        current_post.update(category_id: nil) unless current_post.category_id.nil?
      end

      channels_p = params['channels']&.to_unsafe_h
      if channels_p.present?
        channels_p.each do |k, v|
          if v.to_i == 1 # TODO: make it? Need2fix duplicate content when creating!
            # params["platforms"] = { k=>(v ? 1 : 0).to_s }
            # SendPostToPlatforms.call(@post, params)
          else
            DeletePostMessages.call(current_post, k)
          end
        end
      end

      UpdatePostMessages.call(current_post, posts_params) # TODO: optimize it?
      current_post.update(title: posts_params[:post][:title]) # ?

      redirect_to current_post
    else
      render 'edit'
    end
  end

  def new
    authorize! current_user, to: :create_posts?

    @post = Post.new
  end

  def create
    authorize! current_user, to: :create_posts?

    @post = Post.new(title: posts_params[:post][:title])
    @post.user = current_user
    @post.privacy = posts_params.dig(:post, :privacy) || 2

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
      SendPostToPlatforms.call(@post, posts_params)
      redirect_to @post
    else
      render :new
    end
  end

  def rss
    user =
      if current_user.present?
        current_user
      else
        (User.find_by(rss_token: params[:rss_token]) if params.key?(:rss_token))
      end

    tags = user&.active_tags&.any? ? user&.active_tags&.map { |i| i.tag.id } : Tag.all.ids
    limit = user&.options&.dig('visible_posts_count') || Rails.configuration.credentials[:rss_default_visible_posts]
    post_params = { current_user: user, limit: limit, tags: tags, title: params[:title] }

    @posts = PostsSearch.new(post_params).call(Post.all).order(created_at: (params[:sort] == 'asc' ? 'asc' : 'desc'))

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
        (User.find_by(rss_token: params[:rss_token]) if params.key?(:rss_token))
      end

    post_params = { current_user: user,
                    id: params[:id],
                    user_id: params[:user],
                    strict_tags: params[:tag],
                    text: params[:text],
                    date: params[:to] }

    @posts = PostsSearch.new(post_params).call(Post.all)
    @posts = @posts.paginate(page: params[:page], per_page: 15).order(created_at: (params[:sort] == 'asc' ? 'asc' : 'desc'))
    @last_date = nil

    if Rails.configuration.credentials[:fail2ban][:enabled] && user.nil? && params.key?(:rss_token)
      ip = request.env['action_dispatch.remote_ip'] || request.env['REMOTE_ADDR']
      Rails.logger.error("Failed bypass token from #{ip} at #{Time.now.utc.iso8601}")
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
                         { attachments: [] }])
  end
end
