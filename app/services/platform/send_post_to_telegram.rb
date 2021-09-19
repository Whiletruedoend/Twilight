# frozen_string_literal: true

class Platform::SendPostToTelegram
  prepend SimpleCommand

  attr_accessor :post, :params, :channel_ids

  def initialize(post, params, channel_ids)
    @params = params
    @post = post

    @platform = Platform.find_by(title: 'telegram')

    @channels =
      Channel.where(id: channel_ids).map do |channel|
        { id: channel.id,
          room: channel.room,
          token: channel.token,
          room_attachments: channel.options['room_attachments'] }
      end
    @attachments = @params[:post][:attachments].reverse if @params[:post][:attachments].present?
    @options = @params[:options]
    if @options.present?
      @options =
        @options&.to_unsafe_h&.inject({}) do |h, (k, v)|
          h[k] = (v.to_i == 1)
          h
        end
    end

    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                                                 disable_indented_code_blocks: true, autolink: false,
                                                                 tables: false, underline: false, highlight: false)

    @images = ['image/gif', 'image/jpeg', 'image/pjpeg', 'image/png', 'image/webp', 'image/svg+xml']
    @videos = ['video/mp4', 'video/mpeg', 'video/webm', 'video/ogg']
    @audios = ['audio/mp4',
               'audio/aac',
               'audio/mpeg',
               'audio/ogg',
               'audio/vorbis',
               'audio/webm',
               'audio/vnd.wave',
               'audio/basic']
  end

  def call
    return if @channels.empty?

    title = post.title
    text = params[:post][:content]

    # В первом контенте будет 4096-(длина заголовка) символов. При этом сам заголовок в контенте не хранится
    # (title в посте отдельное поле). Но при рассчёте длины сообщения в телеге мы учитываем длину с заголовком.
    max_first_post_length = title.present? ? (4096 - "<b>#{title}</b>\n\n".length) : 4096

    post_text_blocks = text_blocks(text, max_first_post_length)

    if @attachments.present? # Create first attachment post
      attachment_content = Content.create!(user: @post.user, post: @post, has_attachments: true)
      @attachments.each { |att| attachment_content.attachments.attach(att) } if @attachments.present?
    end

    post_text_blocks.each { |t| Content.create!(user: @post.user, post: @post, text: t) } if post_text_blocks.present?

    @channels.each do |channel|
      options = channel_options(channel)

      if options[:onlylink]
        send_tg_onlylink_post(channel, options)
        next
      end

      send_telegram_content(channel, options) if @post.contents.any?
    end
  end

  def text_blocks(text, length)
    first_text_block =
      ([text.chars.each_slice(length).to_a[0][0..length].join] if text.present?)
    other_text_blocks = text[length..text.length]&.chars&.each_slice(4096)&.map(&:join)

    if first_text_block.present?
      other_text_blocks.present? ? first_text_block + other_text_blocks : first_text_block
    else
      other_text_blocks
    end
  end

  def send_telegram_content(channel, options)
    bot = get_tg_bot(channel)

    full_text = @post.title.present? ? "<b>#{@post.title}</b>\n\n#{@post.text}" : @post.text.to_s
    has_caption = ((full_text.length < 1024) && !full_text.empty?) && @post.contents.order(:id)[0][:has_attachments] &&
                  @options["caption_#{channel[:id]}"]

    @post.contents.order(:id).each_with_index do |content, index|
      has_attachments = content[:has_attachments]
      first_message = @post.contents.order(:id)[0][:has_attachments] ? (index == 1) : (index == 0)

      text = @markdown.render(content[:text]) if content[:text].present?
      text = text.html_to_tg_markdown if content[:text].present?
      text = "<b>#{@post.title}</b>\n\n#{text}" if first_message && @post.title.present? && text.present?

      if has_attachments
        send_telegram_attachments(bot, channel, options, content, has_caption)
      else
        next if has_caption

        @msg = bot.send_message({ chat_id: channel[:room],
                                  text: text,
                                  parse_mode: 'html',
                                  disable_notification: !options[:enable_notifications] })

        PlatformPost.create!(identifier: { chat_id: @msg['result']['chat']['id'],
                                           message_id: @msg['result']['message_id'],
                                           options: options }, platform: @platform,
                             post: @post, content: content, channel_id: channel[:id])
      end
    end
  rescue StandardError
    Rails.logger.error("Failed create telegram message for chat #{channel[:id]} at #{Time.now.utc.iso8601}")
  end

  def send_telegram_attachments(bot, channel, options, content, has_caption)
    full_text = @post.title.present? ? "<b>#{@post.title}</b>\n\n#{@post.text}" : @post.text.to_s
    text = full_text if has_caption

    media = upload_to_telegram(bot, channel[:room_attachments], content)
    msg_ids = []
    # Видео и картиночки могут стакаться, остальное - нет
    begin
      types = media.pluck(:type)
      if ((types.include?('photo') || types.include?('video')) &&
        (types.include?('audio') || types.include?('document'))) || (types.include?('audio') && types.include?('document'))
        # дробим контент и шлём по сообщениям
        m = media.group_by { |x| x[:type] }
        # если сообщения идут группой то caption будет у первой группы в последнем аттачменте
        m[m.keys.first.to_s].last.merge!(caption: text, parse_mode: 'html') if m.present? && text.present?
        m.each do |_k, v|
          msg = bot.send_media_group({ chat_id: channel[:room],
                                       media: v,
                                       disable_notification: !options[:enable_notifications] })
          v.count.times do |i|
            options = options.merge(caption: v[i].key?(:caption))
            msg_ids.append({ chat_id: msg['result'][0]['chat']['id'],
                             message_id: msg['result'][0]['message_id'] + i,
                             file_id: v[i][:media],
                             type: v[i][:type],
                             blob_signed_id: v[i][:blob_signed_id],
                             options: options })
          end
        end
      else
        media.first.merge!(caption: text, parse_mode: 'html') if media.present? && text.present? # First post caption
        msg = bot.send_media_group({ chat_id: channel[:room],
                                     media: media,
                                     disable_notification: !options[:enable_notifications] })
        media.count.times do |i|
          options = options.merge(caption: media[i].key?(:caption))
          msg_ids.append({ chat_id: msg['result'][0]['chat']['id'],
                           message_id: msg['result'][0]['message_id'] + i,
                           file_id: media[i][:media],
                           type: media[i][:type],
                           blob_signed_id: media[i][:blob_signed_id],
                           options: options })
        end
      end
      PlatformPost.create!(identifier: msg_ids, platform: @platform, post: @post,
                           content: content, channel_id: channel[:id])
    rescue StandardError
      Rails.logger.error("Failed create telegram message (attachment) for chat #{channel[:room]} at #{Time.now.utc.iso8601}")
    end
  end

  def upload_to_telegram(bot, room_attachments, content)
    attachment_channel = room_attachments
    content.attachments.order('created_at ASC').map do |att|
      blob_signed_id = att.blob.signed_id
      file = File.open(ActiveStorage::Blob.service.send(:path_for, att.blob.key))
      if @images.include?(att.content_type)
        msg = bot.send_photo({ chat_id: attachment_channel, photo: file })
        { type: 'photo', media: msg['result']['photo'][0]['file_id'], blob_signed_id: blob_signed_id }
      elsif @videos.include?(att.content_type)
        msg = bot.send_video({ chat_id: attachment_channel, video: file })
        { type: 'video', media: msg['result']['video']['file_id'], blob_signed_id: blob_signed_id }
      elsif @audios.include?(att.content_type)
        msg = bot.send_audio({ chat_id: attachment_channel, audio: file })
        { type: 'audio', media: msg['result']['audio']['file_id'], blob_signed_id: blob_signed_id }
      else
        msg = bot.send_document({ chat_id: attachment_channel, document: file })
        { type: 'document', media: msg['result']['document']['file_id'], blob_signed_id: blob_signed_id }
      end
    rescue StandardError
      Rails.logger.error("Failed upload telegram message at #{Time.now.utc.iso8601}")
    end
  end

  def channel_options(channel)
    notification = @options["enable_notifications_#{channel[:id]}"] || false
    onlylink = @options["onlylink_#{channel[:id]}"] || false
    # caption будет только у того сообщения, где реально есть подпись
    caption = false
    { enable_notifications: notification, onlylink: onlylink, caption: caption }
  end

  def get_tg_bot(channel)
    bots_from_config = Telegram.bots_config.select { |_k, v| v == channel[:token] }
    bots_hash = Telegram.bots.select { |k, _v| k == bots_from_config.first[0] }
    bots_hash.first[1]
  end

  def send_tg_onlylink_post(channel, options)
    bot = get_tg_bot(channel)

    post_link = "http://#{Rails.configuration.credentials[:host]}:#{Rails.configuration.credentials[:port]}/posts/#{@post.id}"
    full_post_link = "<a href=\"#{post_link}\">#{post_link}</a>"
    text = @post.title.present? ? "<b>#{@post.title}</b>\n\n#{full_post_link}" : full_post_link

    msg = bot.send_message({ chat_id: channel[:room],
                             text: text,
                             parse_mode: 'html',
                             disable_notification: !options[:enable_notifications] })

    PlatformPost.create!(
      identifier: { chat_id: msg['result']['chat']['id'],
                    message_id: msg['result']['message_id'],
                    options: options },
      platform: @platform,
      post: @post,
      content: @post.contents.first, channel_id: channel[:id]
    )
  rescue StandardError
    Rails.logger.error("Failed create telegram message for chat #{channel[:id]} at #{Time.current.utc.iso8601}")
  end
end
