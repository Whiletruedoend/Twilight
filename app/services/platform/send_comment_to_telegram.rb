# frozen_string_literal: true

class Platform::SendCommentToTelegram
  prepend SimpleCommand

  attr_accessor :params, :channel_ids, :current_post, :current_user

  def initialize(params, channel_ids, current_post, current_user)
    @params = params
    @channel_ids = channel_ids
    @current_post = current_post
    @current_user = current_user

    @platform = Platform.find_by(title: 'telegram')

    @channels =
      Channel.where(id: channel_ids).map do |channel|
        { id: channel.id,
          room: channel.room,
          token: channel.token,
          room_attachments: channel.options['room_attachments'],
          linked_chat_id: channel.options.dig('linked_chat_id'),
        }
      end

    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                                                 disable_indented_code_blocks: true, autolink: false,
                                                                 tables: false, underline: false, highlight: false)
  end

  def call
    return if @channels.empty?

    @channels.each do |channel|
      send_telegram_comment(channel)
    end
  end

  def send_telegram_comment(channel)
    bot = get_tg_bot(channel)

    text = @params[:comment][:text]

    has_attachments = @params.dig(:comment, :attachments)

    platform_post = @current_post.platform_posts.find{ |pp| pp.channel_id == channel[:id] }
    chat_id = platform_post.identifier["chat_id"]
    message_id = platform_post.identifier["linked_chat_message_id"]
    linked_chat_id = channel[:linked_chat_id] # || get_linked_chat(bot, chat_id)
    if linked_chat_id.nil? || message_id.nil?
      return Rails.logger.error("Can't get linked group chat_id or linked message_id for channel #{channel[:id]} at #{Time.now.utc.iso8601}!")
    end

    if @params[:comment][:parent_id].to_i > 0
      parent = current_post.comments.find_by_id(@params[:comment].delete(:parent_id))
      linked_chat_id = parent.identifier["chat_id"]
      message_id = parent.identifier["message_id"]
      parent_id = parent.id 
    end

    if has_attachments.present? && !has_attachments.empty?
      send_telegram_attachments(bot, channel)
    else
      @msg = bot.send_message({ chat_id: linked_chat_id,
                                text: text,
                                reply_to_message_id: message_id,
                                parse_mode: 'html'})

      res = { chat_id: @msg['result']['chat']['id'],
              message_id: @msg['result']['message_id']
              #date: @msg['result']['date'],
            }

      Comment.create!(text: text, identifier: res, post: @current_post, user: @current_user, has_attachments: has_attachments, channel_id: channel[:id], platform: @platform, parent_id: parent_id.present? ? parent_id : nil)
    end
  rescue StandardError => e
    Rails.logger.error("Failed create telegram comment for chat #{channel[:id]} at #{Time.now.utc.iso8601}:\n#{e}")
  end

  def send_telegram_attachments(bot, channel)
    print("NOT IMPLEMENTED YET!")
  end

#  def get_linked_chat(bot, chat_id)
#    begin
      # select only one platform post (make comments for all platform posts is a bad idea)
#      bot.get_chat(chat_id: chat_id).dig('result', 'linked_chat_id')
#    rescue Telegram::Bot::Error
#      errs << 'Channel not available! (Not found or bot access problems?)'
#    end
#  end

  def get_tg_bot(channel)
    Twilight::Application::CURRENT_TG_BOTS.dig((channel[:token]).to_s, :client)
  end
end
