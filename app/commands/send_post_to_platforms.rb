# frozen_string_literal: true

class SendPostToPlatforms
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, params)
    @params = params
    @post = post
    @attachments = @params[:post][:attachments].reverse if @params[:post][:attachments].present?
    @channels = nil
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

    @channels =
      Channel.where(id: channel_ids).map do |channel|
        {
          channel.platform.title => channel.id
        }
      end

    merged =
      @channels.inject do |h1, h2|
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

    @channels = merged.sort_by { |k, _v| k }.reverse.to_h # { "telegram"=>[1, 2], "matrix"=>3 }

    @channels.each do |k, v|
      check_platforms(k, v)
    end
  end

  def check_platforms(platform, channel_ids)
    case platform
    when 'telegram'
      send_telegram_post(channel_ids)
    when 'matrix'
      send_matrix_post(channel_ids)
    end
  end

  ## Telegram ##

  def send_telegram_post(channel_ids)
    channel_ids =
      Channel.where(id: channel_ids).map do |channel|
        { id: channel.id,
          room: channel.room,
          token: channel.token,
          room_attachments: channel.options['room_attachments'] }
      end
    return if channel_ids.empty?

    title = post.title
    text = params[:post][:content]

    # В первом контенте будет 4096-(длина заголовка) символов. При этом сам заголовок в контенте не хранится
    # (title в посте отдельное поле). Но при рассчёте длины сообщения в телеге мы учитываем длину с заголовком.
    max_first_post_length = title.present? ? (4096 - "<b>#{title}</b>\n\n".length) : 4096

    first_text_block =
      ([text.chars.each_slice(max_first_post_length).to_a[0][0..max_first_post_length].join] if text.present?)
    other_text_blocks = text[max_first_post_length..text.length]&.chars&.each_slice(4096)&.map(&:join)

    post_text_blocks =
      if first_text_block.present?
        other_text_blocks.present? ? first_text_block + other_text_blocks : first_text_block
      else
        other_text_blocks
      end

    if @attachments.present? # Create first attachment post
      attachment_content = Content.create!(user: @post.user, post: @post, has_attachments: true)
      @attachments.each { |att| attachment_content.attachments.attach(att) } if @attachments.present?
      # attachments_has_caption = ((full_text.length < 1024) && (full_text.length != 0) )
    end

    post_text_blocks.each { |t| Content.create!(user: @post.user, post: @post, text: t) } if post_text_blocks.present?

    channel_ids.each do |channel|
      options = channel_options(channel)

      if options[:onlylink]
        send_tg_onlylink_post(channel, options)
        next
      end

      send_telegram_content(channel, options) if @post.contents.any?
    end
  end

  def send_telegram_content(channel, options)
    bot = get_tg_bot(channel)

    full_text = @post.title.present? ? "<b>#{@post.title}</b>\n\n#{@post.text}" : @post.text.to_s
    has_caption = ((full_text.length < 1024) && !full_text.empty?) && @post.contents[0][:has_attachments]

    @post.contents.each_with_index do |content, index|
      has_attachments = content[:has_attachments]
      first_message = @post.contents[0][:has_attachments] ? (index == 1) : (index == 0)

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

        PlatformPost.create!(identifier: { chat_id: msg['result']['chat']['id'],
                                           message_id: msg['result']['message_id'],
                                           options: options }, platform: Platform.find_by(title: 'telegram'),
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
        m[m.keys.last.to_s].last.merge!(caption: text, parse_mode: 'html') if m.present? && text.present?
        m.each do |_k, v|
          msg = bot.send_media_group({ chat_id: channel[:room],
                                       media: v,
                                       disable_notification: !options[:enable_notifications] })
          v.count.times do |i|
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
          msg_ids.append({ chat_id: msg['result'][0]['chat']['id'],
                           message_id: msg['result'][0]['message_id'] + i,
                           file_id: media[i][:media],
                           type: media[i][:type],
                           blob_signed_id: media[i][:blob_signed_id],
                           options: options })
        end
      end
      PlatformPost.create!(identifier: msg_ids, platform: Platform.find_by(title: 'telegram'), post: @post,
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
    caption = @options["caption_#{channel[:id]}"] || false
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
      platform: Platform.find_by(title: 'telegram'),
      post: @post,
      content: @post.contents.first, channel_id: channel[:id]
    )
  rescue StandardError
    Rails.logger.error("Failed create telegram message for chat #{channel[:id]} at #{Time.current.utc.iso8601}")
  end

  ## Matrix ##

  def send_matrix_post(channel_ids)
    channel_ids =
      Channel.where(id: channel_ids).map do |channel|
        { id: channel.id, room: channel.room, matrix_token: channel.token, server: channel.options['server'] }
      end

    unless @post.text.present? || (@post.text.blank? && @post.content_attachments.present?) # Content not created!
      content_text = params[:post][:content]

      if @attachments.present?
        attachment_content = Content.create!(user: @post.user, post: @post, has_attachments: true)
        @attachments.each { |att| attachment_content.attachments.attach(att) }
      end
      if content_text.present?
        Content.create!(user: @post.user, post: @post, text: content_text,
                        has_attachments: false)
      end
    end

    # No content - no post :\
    Content.where(post: @post).each do |content|
      title = @post.title

      if content.text.present?
        content_text =
          if Content.where(post: @post, has_attachments: false).count >= 2 # Already upload in tg, also check down below
            @markdown.render(@post.text)
          else # Tg has 1 content or no contents
            @markdown.render(content.text)
          end
        content_text = content_text.replace_html_to_mx_markdown
      end
      text = title.present? ? "<b>#{title}</b><br><br>#{content_text}" : content_text.to_s

      if content.has_attachments?
        send_mx_attachments(channel_ids,content)
      elsif content_text.present?
        send_mx_content(channel_ids, content, text)
        break # If posts exists && content count >2, then for matrix PlatformPost content has first content id
      end
      next if Content.where(post: @post, has_attachments: false).count >= 2
    end
  end

  def send_mx_content(channel_ids,content,text)
    channel_ids.each do |channel|
      options = channel_options(channel)

      if options[:onlylink]
        post_link = "http://#{Rails.configuration.credentials[:host]}:#{Rails.configuration.credentials[:port]}/posts/#{@post.id}"
        full_post_link = "<a href=\"#{post_link}\">#{post_link}</a>"
        text = @post.title.present? ? "<b>#{@post.title}</b><br><br>#{full_post_link}" : full_post_link.to_s
      end

      method = "rooms/#{channel[:room]}/send/m.room.message"
      data = {
        msgtype: 'm.text',
        format: 'org.matrix.custom.html',
        body: text,
        formatted_body: text
      }
      msg = Matrix.post(channel[:server], channel[:matrix_token], method, data)
      identifier = { event_id: JSON.parse(msg)['event_id'], room_id: channel[:room], options: options }
      PlatformPost.create!(identifier: identifier, platform: Platform.find_by(title: 'matrix'), post: @post,
                           content: content, channel_id: channel[:id])
    end
  end

  def upload_to_matrix(channel_ids, content)
    atts = []
    # Upload attachment to matrix servers
    content.attachments.each do |attachment|
      filename = attachment.blob.filename.to_s
      content_type = attachment.blob.content_type
      data = File.read(ActiveStorage::Blob.service.send(:path_for, attachment.blob.key))
      # КОСТЫЛЬ! Ну даже если разные токены, какая разница куда предварительно загружать?
      # Главное чтобы серверы одианковые были, или даже просто связь между ними
      # Ну ладно это угроза безопасности, но если у человека и так есть 2 токена, то не всё ли равно?
      # Разве что что-то заапложенное обнаружит человек у которого есть один токен, то нет второго.
      # Ну не знаю, это специфический случай. Возможно когда-нибудь сделаю его фикс. Когда-нибудь.
      # Возможно.
      msg = Matrix.upload(channel_ids.first[:server], channel_ids.first[:matrix_token], filename, content_type,
                          data)
      content_uri = JSON.parse(msg)['content_uri']
      width = attachment.blob[:metadata][:width].to_i
      height = attachment.blob[:metadata][:height].to_i
      blob_signed_id = attachment.blob.signed_id
      size = attachment.blob.byte_size
      next if msg.blank?

      atts.append({ content_uri: content_uri,
                    filename: filename,
                    size: size,
                    content_type: content_type,
                    width: width,
                    height: height,
                    blob_signed_id: blob_signed_id })
    end
    atts
  end

  def send_mx_attachments(channel_ids, content)
    atts = upload_to_matrix(channel_ids, content)
    # TODO: ENCRYPTED FILE UPLOAD SUPPORT
    channel_ids.each do |channel|
      uploaded_atts = []

      # Only link publish (for 'attachments' method lol)
      options = channel_options(channel)

      if options[:onlylink]
        send_mx_onlylink_post(channel, options)
        next
      end

      atts.each do |uploaded_attachment|
        method = "rooms/#{channel[:room]}/send/m.room.message"
        info = {
          size: uploaded_attachment[:size],
          mimetype: uploaded_attachment[:content_type],
          w: uploaded_attachment[:width],
          h: uploaded_attachment[:height]
        }
        type =
          if @images.include?(uploaded_attachment[:content_type])
            'm.image'
          elsif @videos.include?(uploaded_attachment[:content_type])
            'm.video'
          elsif @audios.include?(uploaded_attachment[:content_type])
            'm.audio'
          else
            'm.file'
          end
        data = {
          msgtype: type,
          url: uploaded_attachment[:content_uri],
          body: uploaded_attachment[:filename],
          info: info
        }
        msg = Matrix.post(channel[:server], channel[:matrix_token], method, data)
        uploaded_atts.append({ event_id: JSON.parse(msg)['event_id'],
                                room_id: channel[:room],
                                options: options,
                                type: type,
                                blob_signed_id: uploaded_attachment[:blob_signed_id] })
      end
      PlatformPost.create!(identifier: uploaded_atts, platform: Platform.find_by(title: 'matrix'), post: @post,
                            content: content, channel_id: channel[:id])
    end
  end

  def send_mx_onlylink_post(channel, options)
    post_link = "http://#{Rails.configuration.credentials[:host]}:#{Rails.configuration.credentials[:port]}/posts/#{@post.id}"
    full_post_link = "<a href=\"#{post_link}\">#{post_link}</a>"
    text = @post.title.present? ? "<b>#{@post.title}</b><br>#{full_post_link}" : full_post_link.to_s

    method = "rooms/#{channel[:room]}/send/m.room.message"
    data = {
      msgtype: 'm.text',
      format: 'org.matrix.custom.html',
      body: text,
      formatted_body: text
    }
    msg = Matrix.post(channel[:server], channel[:matrix_token], method, data)
    identifier = { event_id: JSON.parse(msg)['event_id'], room_id: channel[:room], options: options }
    PlatformPost.create!(identifier: identifier, platform: Platform.find_by(title: 'matrix'), post: @post,
                         content: content, channel_id: channel[:id])
  rescue StandardError
    Rails.logger.error("Failed create matrix message for chat #{channel[:id]} at #{Time.now.utc.iso8601}")
  end
end
