class UpdatePostMessages
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, params)
    @params = params
    @post = post

    @title = post.title
    @content = params[:post][:content]
    @attachments = @params[:post][:attachments]
    @deleted_attachments = @params[:deleted_attachments]
    @text = "<b>#{@title}</b>\n\n#{@content}"
    @length = @text.length

    @only_one_post = true
    @next_post = false

    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false, disable_indented_code_blocks: true, autolink: false, tables: false, underline: false, highlight: false)
  end

  def call
    if @post.platform_posts.empty? # Only site post
      if @attachments.present?
        content = @post.contents.first # first content contains images
        @attachments.each { |image| content.attachments.attach(image) }
        content.update(has_attachments: true) unless content.has_attachments
      end
      @deleted_attachments.each { |attachment| @post.get_content_attachments.find(attachment[0]).purge if attachment[1] == "0" } if @deleted_attachments.present?
      @post.contents.update(text: @content, has_attachments: @post.get_content_attachments.present?)
      return
    end
    update_telegram_posts
  end

  def upload_to_telegram(attachment_content, old_count)
    attachment_channel = Rails.configuration.credentials[:telegram][:attachment_channel_id]
    c = attachment_content.attachments.count - old_count
    attachment_content.attachments.order(:creation_date, :asc).last(c).map do |att|
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

  def update_telegram_posts
    platform_posts = @post.platform_posts.where(platform: Platform.where(title: "telegram"))
    has_attachments = @attachments.present? || @deleted_attachments.present?
    make_checks(platform_posts)
    make_checks_attachments(platform_posts) if has_attachments
    make_fixes if has_attachments
  end

  def make_fixes
    contents = @post.contents
    contents.each_with_index { |c, index| contents[index+1].delete if contents[index+1].present? && (contents[index+1].text == contents[index].text) }
  end

  def make_checks_attachments(platform_posts)
    #if @attachments.present?
    #  content = @post.contents.first # first content contains images
    #  old_count = content.attachments.count
    #  @attachments.each { |image| content.attachments.attach(image) }
    #  content.update(has_attachments: true) unless content.has_attachments

    #  may_caption = !(content.text.length >= 1024) # max caption length
    #  media = upload_to_telegram(content, old_count)

    #  platform_posts.joins(:content).where(messages: { has_attachments: true }).each do |platform_post|
    #    msg = Telegram.bot.edit_message_media({ chat_id: platform_post[:identifier]["chat_id"], message_id: platform_post[:identifier]["message_id"], media: media })
    #  end
    #end
    if @deleted_attachments.present?
      values = @deleted_attachments.to_unsafe_h.values
      del_att = values.each_index.select { |index| values[index] == "0"} # indexes

      platform_posts.joins(:content).where(messages: { has_attachments: true }).each do |platform_post|
        deleted_indexes = []

        del_att.each do |i|
          Telegram.bot.delete_message({ chat_id: platform_post[:identifier][i]["chat_id"], message_id: platform_post[:identifier][i]["message_id"] })
          deleted_indexes.append(i)
        end
        if deleted_indexes.any?
          new_params = platform_post[:identifier].reject.with_index { |e, i| deleted_indexes.include? i }
          if new_params.present? # Ещё есть данные

            if platform_post.content.text.present? # Есть caption?
              begin
                media = { type: "photo", media: new_params[0]["file_id"], caption: platform_post.content.text, parse_mode: "html" } # photo type ???
                Telegram.bot.edit_message_media({ chat_id: new_params[0]["chat_id"], message_id: new_params[0]["message_id"], media: media })
                # По-хорошему если нет аттачментов нужно преобразовать media сообщение в text, но так нельзя поэтому caption удаляется если нет аттачментов
              rescue
                Rails.logger.error("Failed edit caption (BUT IT'S ALMOST NORMAL) for telegram message at #{Time.now.utc.iso8601}")
              end
            end

            platform_post.update!(identifier: new_params)
          else # Данных нет, пост ломаем
            platform_post.delete
          end
        end
      end
      @deleted_attachments.each { |attachment| @post.get_content_attachments.find(attachment[0]).purge if attachment[1] == "0" } if @deleted_attachments.present?
    end
  end

  # KNOWN BUG: If you add new content, title in message don't send
  def make_checks(platform_posts)
    edited_content_id = nil # don't delete him

    platform_posts.each do |platform_post|
      if @length >= 4096
        @only_one_post = false
        clear_text = @next_post ? 0 : @title.length + 9
        platform_post.content.update(text: @text[clear_text...4096])
        begin
          Telegram.bot.edit_message_text({ chat_id: platform_post[:identifier]["chat_id"], message_id: platform_post[:identifier]["message_id"], text: @text[clear_text...4096] })
        rescue # Message don't edit (if you previous text == current text || if bot don't have access to message)
          Rails.logger.error("Failed edit telegram message at #{Time.now.utc.iso8601}")
        end
        @text[0...4096] = ""
        @length -= 4096

        if platform_posts.include?(PlatformPost.find_by_id(platform_post.id+1))
          @next_post = true
          next # We don't need create new platform post
        else # new contents > platform posts, make additional messages!
          @next_post = false
          content = Content.create!(user: @post.user, post: @post, text: @text)
          other_channels = PlatformPost.where(content: platform_post.content, platform: Platform.find_by_title("telegram"), post: @post )
          other_channels.each do |channel|
            begin
              new_text = @markdown.render(@text)
              new_text = new_text.replace_html_to_tg_markdown
              msg = Telegram.bot.send_message({ chat_id: channel[:identifier]["chat_id"], text: new_text, parse_mode: "html" })
            rescue # Message don't send (if bot don't have access to message)
              Rails.logger.error("Failed send telegram message at #{Time.now.utc.iso8601}")
            end
            PlatformPost.create!(identifier: { chat_id: msg["result"]["chat"]["id"], message_id: msg["result"]["message_id"] }, platform: Platform.find_by_title("telegram"), post: @post, content: content)
          end
          next
        end

      else # len < 4096, no need add new contents, but may remove
        if @text.present? # if N contents --> N-1 content and content not empty
          edited_content_id = platform_post.content.id
          clear_text = @only_one_post ? 0 : @title.length + 9
          other_channels = PlatformPost.where(content: platform_post.content, platform: Platform.find_by_title("telegram"), post: @post )
          other_channels.each do |channel|
            begin
              new_text = @markdown.render(@text[clear_text...4096])
              new_text = new_text.replace_html_to_tg_markdown
              Telegram.bot.edit_message_text({ chat_id: channel[:identifier]["chat_id"], message_id: channel[:identifier]["message_id"], text: new_text, parse_mode: "html" })
            rescue # Message don't edit (if you previous text == current text || if bot don't have access to message)
              Rails.logger.error("Failed edit telegram message at #{Time.now.utc.iso8601}")
            end
          end
          clear_text = @only_one_post ? @title.length + 9 : 0 # it's not mistake!
          platform_post.content.update(text: @text[clear_text...4096])
          @text[0...4096] = ""
        else # if N contents --> N-1 content and content is empty (trash)
          other_channels = PlatformPost.where(content: platform_post.content, platform: Platform.find_by_title("telegram"), post: @post )
          other_channels.each do |channel|
            next if edited_content_id.present? && (edited_content_id == channel.content&.id)
            begin
            Telegram.bot.delete_message({ chat_id: channel[:identifier]["chat_id"], message_id: channel[:identifier]["message_id"] })
            rescue # Message don't delete (bot don't have access to message)
              Rails.logger.error("Failed delete telegram message at #{Time.now.utc.iso8601}")
            end
            channel.content.delete if channel.content.present?
            channel.delete
          end
        end
      end
    end

  end
end
