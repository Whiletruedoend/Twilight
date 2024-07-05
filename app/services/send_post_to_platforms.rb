# frozen_string_literal: true

class SendPostToPlatforms
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, base_url, params)
    @params = params
    @post = post
    @base_url = base_url

    @attachments = @params[:post][:attachments].reverse if @params[:post][:attachments].present?
    @options = @params[:options]

    return unless @options.present?

    @options =
      @options&.to_unsafe_h&.inject({}) do |h, (k, v)|
        h[k] = (v.to_i == 1)
        h
      end
  end

  def create_only_site_post
    content = Content.create!(user: @post.user, post: @post, text: params[:post][:content],
                              has_attachments: @attachments.present?)
    @attachments.each { |att| content.attachments.attach(att) } if @attachments.present?
  end

  def call
    return create_only_site_post if params[:channels].nil? || params[:channels].values.exclude?('1')

    channel_ids = []
    params[:channels].to_unsafe_h.select { |_k, v| v == '1' }.each do |k, _v|
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

    # Только так, иначе всё сломается!
    Thread.new do
      execution_context = Rails.application.executor.run!
      channels.each do |k, v|
        check_platforms(k, v)
      ensure
        execution_context&.complete!
      end
    end
  end

  def check_platforms(platform, channel_ids)
    case platform
    when 'telegram'
      Platform::SendPostToTelegram.call(@post, @base_url, params, channel_ids)
    when 'matrix'
      Platform::SendPostToMatrix.call(@post, @base_url, params, channel_ids)
    end
  end
end
