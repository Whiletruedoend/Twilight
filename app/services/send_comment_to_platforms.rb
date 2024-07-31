# frozen_string_literal: true

class SendCommentToPlatforms
  prepend SimpleCommand

  attr_accessor :params, :channel_params, :current_post, :current_user

  def initialize(params, channel_params, current_post, current_user)
    @params = params
    @channel_params = channel_params
    @current_post = current_post
    @current_user = current_user
  end

  def call
    channel_ids = channel_params.map { |k, _v| k }

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
      Platform::SendCommentToTelegram.call(@params, channel_ids, @current_post, @current_user)
    when 'matrix'
      print("NOT IMPLEMENTED YET!")
    end
  end
end
