class SendPostToPlatforms
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, params)
    @params = params
    @post = post
    @attachments = @params[:post][:attachments]

    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                            disable_indented_code_blocks: true, autolink: false, tables: false,
                                            underline: false, highlight: false)
  end

  def call
    if params[:platforms].nil? || params[:platforms].values.exclude?("1")
      content = Content.create!(user: @post.user, post: @post, text: params[:post][:content], has_attachments: @attachments.present?)
      @attachments.each { |att| content.attachments.attach(att) } if @attachments.present?
      return
    end

    params[:platforms].select{ |k,v| v == "1" }.each { |platform| check_platforms(platform[0]) }
  end

  def check_platforms(platform)
    case platform
      when "telegram"
        send_telegram_post
      when "matrix"
        send_matrix_post if Rails.configuration.credentials[:matrix][:enabled]
    end
  end

  def send_matrix_post
    matrix_token = Rails.configuration.credentials[:matrix][:access_token]
    channel_ids = Rails.configuration.credentials[:matrix][:room_ids]

    unless @post.get_content.present? || @post.get_content_attachments.present? # Content not created!
      content_text = params[:post][:content]

      if @attachments.present?
        attachment_content = Content.create!(user: @post.user, post: @post, has_attachments: true)
        @attachments.each { |att| attachment_content.attachments.attach(att) }
      end
      Content.create!(user: @post.user, post: @post, text: content_text, has_attachments: false) if content_text.present?
    end

    Content.where(post: @post).each do |content|
      title = @post.title
      content_text = @markdown.render(content.text) if content.text.present?
      text = title.present? ? "<b>#{title}</b><br><br>#{content_text}" : "#{content_text}"

      if content.has_attachments?
        atts = []

        # Upload attachment to matrix servers
        content.attachments.each do |attachment|
          filename = attachment.blob.filename.to_s
          content_type = attachment.blob.content_type
          data = File.read(ActiveStorage::Blob.service.send(:path_for, attachment.blob.key))
          msg = Matrix.upload(matrix_token, filename, content_type, data)
          content_uri = JSON.parse(msg)["content_uri"]
          width = attachment.blob[:metadata][:width]
          height = attachment.blob[:metadata][:height]
          size = attachment.blob.byte_size
          if msg.present?
            atts.append({ content_uri: content_uri,
                          filename: filename,
                          size: size,
                          content_type: content_type,
                          width: width,
                          height: height })
          end
        end

        # TODO: ENCRYPTED FILE UPLOAD SUPPORT
        channel_ids.each do |room|
          uploaded_atts = []
          atts.each do |uploaded_attachment|
            method = "rooms/#{room}/send/m.room.message"
            data = {
                    "msgtype":"m.image",
                    "url": uploaded_attachment[:content_uri],
                    "body": uploaded_attachment[:filename],
                    "info": {
                        "size": uploaded_attachment[:size],
                        "mimetype": uploaded_attachment[:content_type],
                        "w": uploaded_attachment[:width],
                        "h": uploaded_attachment[:height]
                    }
            }
            msg = Matrix.post(matrix_token, method, data)
            uploaded_atts.append({ event_id: JSON.parse(msg)["event_id"], room_id: room })
          end
          PlatformPost.create!(identifier: uploaded_atts, platform: Platform.find_by_title("matrix"), post: @post, content: content)
        end
      elsif content_text.present?
        channel_ids.each do |room|
          method = "rooms/#{room}/send/m.room.message"
          data = {
              "msgtype":"m.text",
              "format": "org.matrix.custom.html",
              "body": text,
              "formatted_body": text
                }
          msg = Matrix.post(matrix_token, method, data)
          identifier = { event_id: JSON.parse(msg)["event_id"], room_id: room }
          PlatformPost.create!(identifier: identifier, platform: Platform.find_by_title("matrix"), post: @post, content: content)
        end
        break # If posts exists && content count >2, then for matrix PlatformPost content has first content id
      end
    end
  end

  def send_telegram_post
    channel_ids = Rails.configuration.credentials[:telegram][:channel_ids]
    return if channel_ids.empty?

    title = post.title
    content = params[:post][:content]#.replace_markdown_to_symbols # we need: input: html, output: markdown (in the future?)
    text = "**#{title}**\n\n#{content}"

    length = text.length
    created_messages = []

    if @attachments.present? # Create first attachment post
      attachment_content = Content.create!(user: @post.user, post: @post, has_attachments: true)
      @attachments.each { |att| attachment_content.attachments.attach(att) } if @attachments.present?
      att_with_caption = !(length >= 1024) # max caption length
      created_messages.append(attachment_content)
    end

    if length >= 4096
      same_thing = false
      clear_text = title.length + 6
      while (length > 0 || same_thing) && text.present?
        t = same_thing ? text[0...4096] : text[clear_text...4096]
        created_messages.append(Content.create!(user: @post.user, post: @post, text: t))
        text[0...4096] = ""
        length -= 4096
        same_thing = true if length > 0
      end
    else
      created_messages.append(Content.create!(user: @post.user, post: @post, text: content))
    end

    channel_ids.each do |channel_id|
      first_message = true
      created_messages.each do |message|

        has_attachments = message.has_attachments
        text = first_message ? "**#{title}**\n\n#{message[:text]}" : message[:text]
        text = created_messages[1][:text] if first_message && att_with_caption # first message - images, second message - text
        first_message = false unless has_attachments
        text = @markdown.render(text) if text.present?
        text = text.replace_html_to_tg_markdown if text.present?

        begin
          if first_message && has_attachments
            if att_with_caption
              text.present? ? send_telegram_attachments(channel_id, attachment_content, text) : send_telegram_attachments(channel_id, attachment_content)
              break
            else
              send_telegram_attachments(channel_id, attachment_content)
            end
          else
            msg = Telegram.bot.send_message({ chat_id: channel_id, text: text, parse_mode: "html" })
            PlatformPost.create!(identifier: { chat_id: msg["result"]["chat"]["id"], message_id: msg["result"]["message_id"] }, platform: Platform.find_by_title(platform), post: @post, content: message)
          end
        rescue
          Rails.logger.error("Failed create telegram message for chat #{channel_id} at #{Time.now.utc.iso8601}")
        end
      end
    end
  end

  def send_telegram_attachments(channel_id, attachment_content, text=nil)
    media = upload_to_telegram(attachment_content)
    media.first.merge!(caption: text, parse_mode: "html") if media.present? && text.present?

    begin
      msg = Telegram.bot.send_media_group({ chat_id: channel_id, media: media })
      msg_ids = []
      media.count.times { |i| msg_ids.append({ chat_id: msg["result"][0]["chat"]["id"], message_id: msg["result"][0]["message_id"] + i, file_id: media[i][:media] }) }
      PlatformPost.create!(identifier: msg_ids, platform: Platform.find_by_title("telegram"), post: @post, content: attachment_content)
    rescue
      Rails.logger.error("Failed create telegram message for chat #{channel_id} at #{Time.now.utc.iso8601}")
    end
  end

  def upload_to_telegram(attachment_content)
    attachment_channel = Rails.configuration.credentials[:telegram][:attachment_channel_id]
    attachment_content.attachments.order(:creation_date, :asc).map do |att|
      begin
        file = File.open(ActiveStorage::Blob.service.send(:path_for, att.blob.key))
        msg = Telegram.bot.send_photo({ chat_id: attachment_channel, photo: file })
      rescue
        Rails.logger.error("Failed upload telegram message at #{Time.now.utc.iso8601}")
      end
      {
          type: "photo", # todo: add more types
          media: msg["result"]["photo"][0]["file_id"]
      }
    end
  end
end