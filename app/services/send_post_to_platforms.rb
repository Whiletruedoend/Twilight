# frozen_string_literal: true

class SendPostToPlatforms
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, base_url, params)
    @params = params.to_unsafe_h
    @post = post
    @base_url = base_url

    @attachments = @params[:post][:attachments].reverse if @params[:post][:attachments].present?
    @options = @params[:options]

    return unless @options.present?

    @options =
      @options&.inject({}) do |h, (k, v)|
        h[k] = (v.to_i == 1)
        h
      end
  end

  def create_blog_post
    platform = Platform.find_by(title: 'blog')
    # return when update post && create for new channels
    return if @post.contents.find{|c| c.platform == platform }.present?

    if @attachments.present?
      attachments_content = Content.create!(user: @post.user, post: @post, text: nil,
                                            has_attachments: true, platform: platform)
      @attachments.each { |att| @post.attachments.attach(att) }
      attachments_content.upd_post
    end

    if params[:post][:content].present? && !params[:post][:content].empty?
      content = Content.create!(user: @post.user, post: @post, text: params[:post][:content],
                                has_attachments: false, platform: platform)
      content.upd_post
    end
  end

  def call
    create_blog_post
    return if params[:channels].nil? || params[:channels].values.exclude?('1')

    channel_ids = []
    params[:channels].select { |_k, v| v == '1' }.each do |k, _v|
      channel_ids.append(k)
    end

    channels =
      Channel.where(id: channel_ids).map do |channel|
        {
          channel.platform.title => channel.id
        }
      end

    merged =
      channels.inject do |h1, h2|
        h1.merge(h2) do |_k, v1, v2|
          if v1 == v2
            v1
          elsif v1.is_a?(Hash) && v2.is_a?(Hash)
            v1.merge(v2)
          else
            [*v1, *v2]
          end
        end
      end

    channels = merged.sort_by { |k, _v| k }.reverse.to_h # { "telegram"=>[1, 2], "matrix"=>3 }

    channels.each do |k, v|
      check_platforms(k, v)
    end
  end

  def check_platforms(platform, channel_ids)
    case platform
    when 'telegram'
      SendPostToTelegram.perform_later(@post.id, @base_url, @params, channel_ids)
    when 'matrix'
      SendPostToMatrix.perform_later(@post.id, @base_url, @params, channel_ids)
    end
  end
end
