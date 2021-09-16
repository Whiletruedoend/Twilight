# frozen_string_literal: true

class Platform::SendPostToMatrix
  prepend SimpleCommand

  attr_accessor :post, :params, :channel_ids

  def initialize(post, params, channel_ids)
    @params = params
    @post = post
    @channels =
      Channel.where(id: channel_ids).map do |channel|
        { id: channel.id, room: channel.room, matrix_token: channel.token, server: channel.options['server'] }
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
        send_mx_attachments(content)
      elsif content_text.present?
        send_mx_content(content, text)
        break # If posts exists && content count >2, then for matrix PlatformPost content has first content id
      end
      next if Content.where(post: @post, has_attachments: false).count >= 2
    end
  end

  def send_mx_content(content, text)
    @channels.each do |channel|
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

  def send_mx_attachments(content)
    atts = upload_to_matrix(content)
    # TODO: ENCRYPTED FILE UPLOAD SUPPORT
    @channels.each do |channel|
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

  def upload_to_matrix(content)
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
      msg = Matrix.upload(@channels.first[:server], @channels.first[:matrix_token], filename, content_type,
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

  def channel_options(channel)
    notification = @options["enable_notifications_#{channel[:id]}"] || false
    onlylink = @options["onlylink_#{channel[:id]}"] || false
    caption = @options["caption_#{channel[:id]}"] || false
    { enable_notifications: notification, onlylink: onlylink, caption: caption }
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
