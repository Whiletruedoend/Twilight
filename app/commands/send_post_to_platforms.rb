class SendPostToPlatforms
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, params)
    @params = params
    @post = post
    @attachments = @params[:post][:attachments]
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

  def send_telegram_attachments(channel_id, attachment_content, text=nil)
    media = upload_to_telegram(attachment_content)
    media.first.merge!(caption: text, parse_mode: "html") if media.present? && text.present?

    begin
      msg = Telegram.bot.send_media_group({ chat_id: channel_id, media: media })
      PlatformPost.create!(identifier: { chat_id: msg["result"][0]["chat"]["id"], message_id: msg["result"][0]["message_id"] }, platform: Platform.find_by_title("telegram"), post: @post, content: attachment_content)
    rescue
      Rails.logger.error("Failed create telegram message for chat #{channel_id} at #{Time.now.utc.iso8601}")
    end
  end

  def call
    if params[:platforms].nil? || params[:platforms].values.exclude?("1")
      content = Content.create!(user: @post.user, post: @post, text: params[:post][:content], has_attachments: @attachments.present?)
      @attachments.each { |att| content.attachments.attach(att) } if @attachments.present?
      return
    end

    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                       disable_indented_code_blocks: true, autolink: false, tables: false,
                                       underline: false, highlight: false)

    params[:platforms].select{ |k,v| v == "1" }.each do |platform|
      case platform[0]
        when "telegram"
          channel_ids = Rails.configuration.credentials[:telegram][:channel_ids]
          next if channel_ids.empty?

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
              text = markdown.render(text) if text.present?
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
        else # todo: moare platforms!
          nil
      end
    end
  end
end