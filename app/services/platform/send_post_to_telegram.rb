# frozen_string_literal: true

class Platform::SendPostToTelegram
  prepend SimpleCommand

  attr_accessor :post, :params, :channel_ids

  def initialize(post, base_url, params, channel_ids)
    @params = params
    @post = post
    @base_url = base_url

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

    # The first content will have (4096-(title length)) chars. At the same time, the title itself is not stored in the content.
    # (title is a separate field in the post). But when calculating the length of the message in tg,
    # we take into account the length with the title.
    max_first_post_length = title.present? ? (4096 - "<b>#{title}</b>\n\n".length) : 4096

    post_text_blocks = text_blocks(text, max_first_post_length)

    if post_text_blocks.present?
      text_contents = post_text_blocks.map { |t| Content.create!(user: @post.user, post: @post, 
                                                  text: t, platform: @platform, has_attachments: false) 
                                          }
    else # Only title without text or attachments case
      text_contents = [Content.create!(user: @post.user, post: @post, 
                                       text: "", platform: @platform, has_attachments: false) ]
    end
 
    use_attachment_channel = (1 == 1) # TMP!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    if use_attachment_channel
      already_uploaded_media = []
      channel_with_roomatt = @channels.find{ |ch| ch[:room_attachments].present? && !ch[:room_attachments].empty? }
      if channel_with_roomatt.present?
        if already_uploaded_media.empty?
          media = upload_to_attachment_channel(channel_with_roomatt)
          already_uploaded_media = media
        else
          media = already_uploaded_media
        end
      else
        # We select 'Upload to attachment channel', but channels with att room not found. So, we do each-channel upload
        use_attachment_channel = false
      end
    end
    
    @channels.each do |channel|
      options = channel_options(channel)

      bot = get_tg_bot(channel)

      if options[:onlylink]
        send_tg_onlylink_post(bot, channel, options)
        next
      end

      if @post.attachments.present?
        if !use_attachment_channel
          media = prepare_media_to_upload()
        end

        full_text = @post.title.present? ? "<b>#{@post.title}</b>\n\n#{@post.text}" : @post.text.to_s
        has_caption = ((full_text.length < 1024) && !full_text.empty?) && @options["caption_#{channel[:id]}"]

        send_telegram_attachments(bot, channel, options, has_caption, media)
        next if has_caption
      end

      next unless text_contents.present?
      text_contents.each_with_index do |text_content, index|
        next if !title.present? && (!text_content.text.present? || text_content.text.empty?)
        send_telegram_content(bot, channel, text_content, options, index)
      end
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

  def send_telegram_content(bot, channel, text_content, options, index)
    first_message = text_content[:has_attachments] ? (index == 1) : (index == 0)
    text = @markdown.render(text_content.text) 
    text = text.html_to_tg_markdown
    if first_message && @post.title.present?
      if text.present?
        text = "<b>#{@post.title}</b>\n\n#{text}" 
      else
        text = "#{@post.title}"
      end
    end

    @msg = bot.send_message({ chat_id: channel[:room],
                              text: text,
                              parse_mode: 'html',
                              disable_notification: !options[:enable_notifications] })

    PlatformPost.create!(identifier: { chat_id: @msg['result']['chat']['id'],
                                       message_id: @msg['result']['message_id'],
                                       date: @msg['result']['date'],
                                       options: options }, platform: @platform,
                         post: @post, content: text_content, channel_id: channel[:id]
                        )
  rescue StandardError => e
    Rails.logger.error("Failed create telegram message for chat #{channel[:id]} at #{Time.now.utc.iso8601}:\n#{e}".red)
  end

  def send_telegram_attachments(bot, channel, options, has_caption, media)
    full_text = @post.title.present? ? "<b>#{@post.title}</b>\n\n#{@post.text}" : @post.text.to_s
    text = full_text if has_caption

    attachment_content = @post.contents.where(platform: @platform).find{ |c| c.has_attachments }
    unless attachment_content.present?
      attachment_content = Content.create!(post: @post, user: @post.user, 
                                           platform: @platform, has_attachments: true)
    end
    
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
                             date: msg['result'][0]['date'],
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
                           date: msg['result'][0]['date'],
                           file_id: media[i][:media],
                           type: media[i][:type],
                           blob_signed_id: media[i][:blob_signed_id],
                           options: options })
        end
      end
      PlatformPost.create!(identifier: msg_ids, platform: @platform, post: @post,
                           content: attachment_content, channel_id: channel[:id])
    rescue StandardError => e
      Rails.logger.error("Failed create tg message (attachment) for chat #{channel[:room]} at #{Time.now.utc.iso8601}:\n#{e}".red)
    end
  end

  def prepare_media_to_upload
    @post.attachments.order('created_at ASC').map do |att|
      blob_signed_id = att.blob.signed_id
      file = File.open(ActiveStorage::Blob.service.send(:path_for, att.blob.key))
      if @images.include?(att.content_type)
        { type: 'photo', media: file, blob_signed_id: blob_signed_id }
      elsif @videos.include?(att.content_type)
        { type: 'video', media: file, blob_signed_id: blob_signed_id }
      elsif @audios.include?(att.content_type)
        { type: 'audio', media: file, blob_signed_id: blob_signed_id }
      else
        { type: 'document', media: file, blob_signed_id: blob_signed_id }
      end
    end
  end

  # Faster than upload to each channel, but requires attachment channel
  def upload_to_attachment_channel(channel)
    bot = get_tg_bot(channel)
    attachment_channel = channel[:room_attachments]
    @post.attachments.order('created_at ASC').map do |att|
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
    rescue StandardError => e
      Rails.logger.error("Failed upload telegram message at #{Time.now.utc.iso8601}:\n#{e}".red)
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
    Twilight::Application::CURRENT_TG_BOTS.dig((channel[:token]).to_s, :client)
  end

  def send_tg_onlylink_post(bot, channel, options)
    post_link = "#{@base_url}/posts/#{@post.slug_url}"
    full_post_link = "<a href=\"#{post_link}\">#{post_link}</a>"
    text = @post.title.present? ? "<b>#{@post.title}</b>\n\n#{full_post_link}" : full_post_link

    msg = bot.send_message({ chat_id: channel[:room],
                             text: text,
                             parse_mode: 'html',
                             disable_notification: !options[:enable_notifications] })

    content = @post.contents.where(platform: @platform, has_attachments: false)&.first
    content = @post.contents.where(platform: @platform, has_attachments: true)&.first if content.nil?
    if content.nil? # Send 'link only' to platforms where post is empty (no text or attachments). Ok... 
      content = Content.create!(user: @post.user, post: @post, 
                                text: text, platform: @platform, has_attachments: false) 
    end
    
    PlatformPost.create!(
      identifier: { chat_id: msg['result']['chat']['id'],
                    message_id: msg['result']['message_id'],
                    date: msg['result']['date'],
                    options: options },
      platform: @platform,
      post: @post,
      content: content, channel_id: channel[:id]
    )
  rescue StandardError => e
    Rails.logger.error("Failed create telegram message for chat #{channel[:id]} at #{Time.current.utc.iso8601}:\n#{e}".red)
  end
end
