# frozen_string_literal: true

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

    # For matrix
    @attachments_count = @post.content_attachments&.count || 0

    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                                                 disable_indented_code_blocks: true, autolink: false,
                                                                 tables: false, underline: false, highlight: false)
  end

  def call
    if @post.platform_posts.empty? # Only site post
      if @attachments.present?
        content = @post.contents.first # first content contains images
        @attachments.each { |image| content.attachments.attach(image) }
        content.update(has_attachments: true) unless content.has_attachments
      end
      if @deleted_attachments.present?
        @deleted_attachments.each do |attachment|
          if attachment[1] == '0'
            @post.content_attachments.find_by(blob_id: ActiveStorage::Blob.find_signed!(attachment[0]).id).purge
          end
        end
      end
      # fix if platform was deleted, but content still exist
      @post.contents.last(@post.contents.count - 1).each(&:delete) if @post.contents.count > 1
      @post.contents.update(text: @content, has_attachments: @post.content_attachments.present?)
      return
    end

    posted_platforms = @post.platforms

    update_telegram_posts if posted_platforms['telegram']
    update_matrix_posts if posted_platforms['matrix']
  end

  def update_telegram_posts
    has_attachments = @attachments.present? || @deleted_attachments.present?
    platform_posts = @post.platform_posts.where(platform: Platform.where(title: 'telegram'))

    make_checks(@post.platform_posts.joins(:content).where(contents: { has_attachments: false },
                                                           platform: Platform.where(title: 'telegram')))
    make_caption_fixes(platform_posts)
    make_checks_attachments(platform_posts) if has_attachments
    make_fixes(platform_posts) if has_attachments
  end

  def make_caption_fixes(platform_posts)
    platform_posts.joins(:content).where(contents: { has_attachments: true }).each do |platform_post|
      bots_from_config = Telegram.bots_config.select { |_k, v| v == platform_post.channel.token }
      bots_hash = Telegram.bots.select { |k, _v| k == bots_from_config.first[0] }
      bot = bots_hash.first[1]

      next if platform_post.identifier.dig('options', 'onlylink')

      current_content = platform_post.content
      next_content = Content.find_by(id: platform_post.content.id + 1)

      if @content.present? && @length < 1024
        current_content.update!(text: nil)
        next_content.update!(text: @content) if next_content.present?
        # elsif @length >= 1024
        # current_content.update!(text: nil)
      end

      if current_content.text&.present? # Есть caption?
        edit_media_caption(bot, platform_post[:identifier][0], current_content)
      elsif next_content.text&.present?
        edit_media_caption(bot, platform_post[:identifier][0], next_content)
      end
    end
  end

  def make_fixes(platform_posts)
    contents = @post.contents
    contents.each_with_index do |_c, index|
      contents[index + 1].delete if contents[index + 1].present? && (contents[index + 1].text == contents[index].text)
    end

    return unless @attachments.blank? && @deleted_attachments.blank? # Fix (cuz make_checks (attachments is false) )

    platform_posts.joins(:content).where(contents: { has_attachments: true }).each do |platform_post|
      bots_from_config = Telegram.bots_config.select { |_k, v| v == platform_post.channel.token }
      bots_hash = Telegram.bots.select { |k, _v| k == bots_from_config.first[0] }
      bot = bots_hash.first[1]

      next_content = Content.find_by(id: platform_post.content.id + 1)
      edit_media_caption(bot, platform_post[:identifier][0], next_content) if next_content&.text&.present?
    end
  end

  def edit_media_caption(bot, first_identifier, content)
    media = { type: 'photo', media: first_identifier['file_id'], caption: content.text, parse_mode: 'html' } # photo type ???
    bot.edit_message_media({ chat_id: first_identifier['chat_id'],
                             message_id: first_identifier['message_id'],
                             media: media })
  # По-хорошему если нет аттачментов нужно преобразовать media сообщение в text, но так нельзя
  # поэтому caption удаляется если нет аттачментов
  rescue StandardError
    Rails.logger.error("Failed edit caption (BUT IT'S ALMOST NORMAL) for telegram message at #{Time.now.utc.iso8601}")
  end

  def make_checks_attachments(platform_posts)
    return if @deleted_attachments.blank?

    attachments = @deleted_attachments.to_unsafe_h
    del_att = attachments.select { |val| attachments[val] == '0' }

    platform_posts.joins(:content).where(contents: { has_attachments: true }).each do |platform_post|
      bots_from_config = Telegram.bots_config.select { |_k, v| v == platform_post.channel.token }
      bots_hash = Telegram.bots.select { |k, _v| k == bots_from_config.first[0] }
      bot = bots_hash.first[1]

      deleted_indexes = []

      del_att.each do |k, _v|
        attachment = platform_post[:identifier].select { |att| att['blob_signed_id'] == k }
        i = platform_post[:identifier].index { |x| attachment.include?(x) }
        bot.delete_message({ chat_id: platform_post[:identifier][i]['chat_id'],
                             message_id: platform_post[:identifier][i]['message_id'] })
        deleted_indexes.append(i)
      end
      next unless deleted_indexes.any?

      new_params = platform_post[:identifier].reject.with_index { |_e, i| deleted_indexes.include? i }
      if new_params.present? # Ещё есть данные

        current_content = platform_post.content
        next_content = Content.find_by(id: platform_post.content.id + 1)

        if current_content.text&.present? # Есть caption?
          edit_media_caption(bot, new_params[0], current_content)
        elsif next_content.text&.present?
          edit_media_caption(bot, new_params[0], next_content)
        end

        platform_post.update!(identifier: new_params)
      else # Данных нет, пост ломаем
        platform_post.delete
      end
    end

    return if @deleted_attachments.blank?

    @deleted_attachments.each do |attachment|
      @post.content_attachments.find_by(blob_id: ActiveStorage::Blob.find_signed!(attachment[0]).id).purge if attachment[1] == '0'
    end
  end

  # KNOWN BUG: If you add new content, title in message don't send
  def make_checks(platform_posts)
    edited_content_id = nil # don't delete him

    platform_posts.each do |platform_post|
      bots_from_config = Telegram.bots_config.select { |_k, v| v == platform_post.channel.token }
      bots_hash = Telegram.bots.select { |k, _v| k == bots_from_config.first[0] }
      bot = bots_hash.first[1]

      next if platform_post.identifier.dig('options', 'onlylink')

      if @length >= 4096
        @only_one_post = false
        clear_text = @next_post ? 0 : @title.length + 9
        platform_post.content.update(text: @text[clear_text...4096])
        post_identifier = platform_post[:identifier]
        begin
          bot.edit_message_text({ chat_id: post_identifier['chat_id'],
                                  message_id: post_identifier['message_id'],
                                  text: @text[clear_text...4096] })
        rescue StandardError # Message don't edit (if you previous text == current text || if bot don't have access to message)
          Rails.logger.error("Failed edit telegram message at #{Time.now.utc.iso8601}")
        end
        @text[0...4096] = ''
        @length -= 4096

        if platform_posts.include?(PlatformPost.find_by(id: platform_post.id + 1))
          @next_post = true
        else # new contents > platform posts, make additional messages!
          @next_post = false
          content = Content.create!(user: @post.user, post: @post, text: @text)
          other_channels = PlatformPost.where(content: platform_post.content,
                                              platform: Platform.find_by(title: 'telegram'), post: @post)
          other_channels.each do |channel|
            begin
              new_text = @markdown.render(@text)
              new_text = new_text.html_to_tg_markdown

              # если несколько сообщений, берём последнее, ибо какая разница, всё равно одни и те же опции
              options = post_identifier.is_a?(Array) ? post_identifier.last['options'] : post_identifier['options']
              option_notification = options['enable_notifications'] || false

              msg = bot.send_message({ chat_id: channel[:identifier]['chat_id'],
                                       text: new_text,
                                       parse_mode: 'html',
                                       disable_notification: !option_notification })
            rescue StandardError # Message don't send (if bot don't have access to message)
              Rails.logger.error("Failed send telegram message at #{Time.now.utc.iso8601}")
            end
            PlatformPost.create!(
              identifier: { chat_id: msg['result']['chat']['id'],
                            message_id: msg['result']['message_id'] },
              platform: Platform.find_by(title: 'telegram'),
              post: @post, content: content,
              channel_id: channel.channel.id
            )
          end
        end
        next

      elsif @text.present? # len < 4096, no need add new contents, but may remove
        edited_content_id = platform_post.content.id
        clear_text = @only_one_post ? 0 : @title.length + 9
        other_channels = PlatformPost.where(content: platform_post.content,
                                            platform: Platform.find_by(title: 'telegram'), post: @post)
        other_channels.each do |channel|
          new_text = @markdown.render(@text[clear_text...4096])
          new_text = new_text.html_to_tg_markdown
          bot.edit_message_text({ chat_id: channel[:identifier]['chat_id'],
                                  message_id: channel[:identifier]['message_id'],
                                  text: new_text,
                                  parse_mode: 'html' })
        rescue StandardError # Message don't edit (if you previous text == current text || if bot don't have access to message)
          Rails.logger.error("Failed edit telegram message at #{Time.now.utc.iso8601}")
        end
        clear_text = @only_one_post ? @title.length + 9 : 0 # it's not mistake!
        platform_post.content.update(text: @text[clear_text...4096])
        @text[0...4096] = '' # if N contents --> N-1 content and content not empty
      else # if N contents --> N-1 content and content is empty (trash)
        other_channels = PlatformPost.where(content: platform_post.content,
                                            platform: Platform.find_by(title: 'telegram'), post: @post)
        other_channels.each do |channel|
          next if edited_content_id.present? && (edited_content_id == channel.content&.id)

          begin
            bot.delete_message({ chat_id: channel[:identifier]['chat_id'],
                                 message_id: channel[:identifier]['message_id'] })
          rescue StandardError # Message don't delete (bot don't have access to message)
            Rails.logger.error("Failed delete telegram message at #{Time.now.utc.iso8601}")
          end
          channel.content.delete if channel.content.present?
          channel.delete
        end
      end
    end
  end

  def update_matrix_posts
    platform_posts = @post.platform_posts.where(platform: Platform.where(title: 'matrix'))
    need_delete_attachments = false

    if @deleted_attachments.present?
      attachments = @deleted_attachments.to_unsafe_h
      del_att = attachments.select { |val| attachments[val] == '0' }
      need_delete_attachments = true if del_att.any?

      platform_posts.joins(:content).where(contents: { has_attachments: true }).each do |platform_post|
        next if platform_post.identifier.dig('options', 'onlylink')

        matrix_token = platform_post.channel.token
        server = platform_post.channel.options['server']

        deleted_indexes = []
        del_att.each do |k, _v|
          attachment = platform_post[:identifier].select { |att| att['blob_signed_id'] == k }
          i = platform_post[:identifier].index { |x| attachment.include?(x) }
          method = "rooms/#{platform_post[:identifier][i]['room_id']}/redact/#{platform_post[:identifier][i]['event_id']}"
          data = { reason: "Delete post ##{platform_post.post_id}" }
          Matrix.post(server, matrix_token, method, data)
          deleted_indexes.append(i)
        end
        if deleted_indexes.any?
          new_params = platform_post[:identifier].reject.with_index { |_e, i| deleted_indexes.include? i }
          new_params.present? ? platform_post.update!(identifier: new_params) : platform_post.delete
        end
      end

    end

    # Если есть изменения и не обновился в предыдущих платформах, то обновляем тут
    if @content.length != @post.text.length
      # отсутствие контента - это content?
      content = @post.contents.where(has_attachments: false).first # first тому что matrix только 1 контент

      if content.present?
        content.update(text: @content)
      elsif content.nil? && !@content.empty?
        Content.create!(user: @post.user, post: @post, text: @content)
      end
    end

    text =
      if @title.present? && @content.present?
        "<b>#{@title}</b><br><br>#{@content}"
      elsif @title.present? && @content.empty?
        @post.title
      else
        @content
      end
    text = @markdown.render(text)
    text = text.replace_html_to_mx_markdown if text.present?

    platform_posts.joins(:content).where(contents: { has_attachments: false }).each do |platform_post|
      next if platform_post.identifier.dig('options', 'onlylink')

      matrix_token = platform_post.channel.token
      server = platform_post.channel.options['server']
      method = "rooms/#{platform_post[:identifier]['room_id']}/send/m.room.message"
      data = {
        msgtype: 'm.text',
        format: 'org.matrix.custom.html',
        body: text,
        formatted_body: text,
        'm.new_content': {
          msgtype: 'm.text',
          format: 'org.matrix.custom.html',
          body: text,
          formatted_body: text
        },
        'm.relates_to': {
          event_id: platform_post[:identifier]['event_id'],
          rel_type: 'm.replace'
        }
      }
      Matrix.post(server, matrix_token, method, data)
    end

    # Fix if has telegram post && attachments has caption && update from nil to text, send msg
    fix_content = platform_posts.joins(:content).where(contents: { has_attachments: false }).none?

    if fix_content # Постим недостающее сообщение с текстом
      channel_ids =
        @post.user.channels.where(platform: Platform.find_by(title: 'matrix')).map do |channel|
          { id: channel.id, room: channel.room, token: channel.token, server: channel.options['server'] }
        end
      channel_ids.each do |channel|
        method = "rooms/#{channel[:room]}/send/m.room.message"
        data = {
          msgtype: 'm.text',
          format: 'org.matrix.custom.html',
          body: text,
          formatted_body: text
        }
        msg = Matrix.post(channel[:server], channel[:token], method, data)
        identifier = { event_id: JSON.parse(msg)['event_id'], room_id: channel[:room] }
        PlatformPost.create!(identifier: identifier, platform: Platform.find_by(title: 'matrix'), post: @post,
                             content: @post.contents.where(has_attachments: false).first, channel_id: channel[:id])
      end
      # elsif fix_content && @title.empty? && @content.empty? # Delete if text not present
      # platform_posts.joins(:content).where(contents: { has_attachments: false }).each do |platform_post|
      # method = "rooms/#{platform_post[:identifier]["room_id"]}/redact/#{platform_post[:identifier]["event_id"]}"
      # data = { reason: "Delete post ##{platform_post.post_id}" }
      # Matrix.post(matrix_token, method, data)
      # platform_post.delete
      # end
    end

    unless need_delete_attachments && @deleted_attachments.present? &&
           @attachments_count == (@post.content_attachments&.count || 0)
      return
    end

    @deleted_attachments.each do |attachment|
      @post.content_attachments.find_by(blob_id: ActiveStorage::Blob.find_signed!(attachment[0]).id).purge if attachment[1] == '0'
    end
  end
end