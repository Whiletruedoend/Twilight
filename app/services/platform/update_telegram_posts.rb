# frozen_string_literal: true

class Platform::UpdateTelegramPosts
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, params)
    @params = params
    @post = post

    # @title = post.title
    # @content = params[:post][:content]

    @platform_posts = @post.platform_posts.where(platform: Platform.where(title: 'telegram'))
    @deleted_attachments = @params[:deleted_attachments].to_unsafe_h.select { |_k, v| v == '0' }.keys
    # need sort @deleted_attachments in the order of their posting platforms (grouping of pictures)
    @attachments = @post.content_attachments.map { |att| att.blob.signed_id }
    @deleted_attachments = @attachments.select { |att| att.in?(@deleted_attachments) }

    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                                                 disable_indented_code_blocks: true, autolink: false,
                                                                 tables: false, underline: false, highlight: false)
  end

  def call
    # has_attachments = @attachments.present? || @deleted_attachments.present?

    # make_checks(@post.platform_posts.joins(:content).where(contents: { has_attachments: false },
    #                                                       platform: Platform.where(title: 'telegram')))
    # make_caption_fixes(platform_posts)
    # make_checks_attachments(platform_posts) if has_attachments
    # make_fixes(platform_posts) if has_attachments

    delete_attachments if @deleted_attachments.any?
  end

  def delete_attachments
    @platform_posts.joins(:content).where(contents: { has_attachments: true }).each do |platform_post|
      bot = get_tg_bot(platform_post)

      deleted_indexes = []

      @deleted_attachments.each do |del_att|
        attachment = platform_post[:identifier].select { |att| att['blob_signed_id'] == del_att }
        i = platform_post[:identifier].index { |x| attachment.include?(x) }
        deleted_indexes.append(i)
      end

      caption_identifier = platform_post.identifier.each_with_index.filter_map { |x, i| i if x.dig('options', 'caption') }

      if caption_identifier.present? && deleted_indexes.include?(caption_identifier[0])
        new_caption_identifier = move_caption(bot, platform_post, deleted_indexes)
      end

      deleted_indexes.each do |i|
        bot.delete_message({ chat_id: platform_post[:identifier][i]['chat_id'],
                             message_id: platform_post[:identifier][i]['message_id'] })
      end

      new_identifier = platform_post[:identifier].reject.with_index { |_e, i| deleted_indexes.include? i }

      if new_caption_identifier.present?
        new_caption_identifier['options'] =
          new_caption_identifier['options'].merge(caption: true)
      end
      new_identifier.empty? ? platform_post.delete : platform_post.update!(identifier: new_identifier)
    end

    return if @deleted_attachments.blank?

    @deleted_attachments.each do |attachment|
      @post.content_attachments.find_by(blob_id: ActiveStorage::Blob.find_signed!(attachment).id).purge
    end
  end

  def move_caption(bot, platform_post, deleted_indexes)
    all_indexes = *(0..(platform_post.identifier.count - 1))
    return if all_indexes == deleted_indexes

    caption_identifier =
      platform_post.identifier.each_with_index.filter_map do |x, i|
        { i => x['type'] } if x.dig('options', 'caption')
      end

    available_identifiers =
      platform_post.identifier.each_with_index.filter_map do |x, i|
        { i => x['type'] } if (all_indexes - deleted_indexes).include?(i)
      end

    a = (available_identifiers + caption_identifier).sort_by { |e| e.keys.first } # idk how to name it
    index_caption_identifier_in_a = a.each_index.find { |index| a[index] == caption_identifier[0] }

    future_identifier_index =
      if index_caption_identifier_in_a == 0
        a[1].keys.first
      # if caption element is last, move in previous
      elsif index_caption_identifier_in_a == a.count
        a[a.count - 2].keys.first
      # if previous element has type is the same as caption, move caption in him
      elsif a[index_caption_identifier_in_a - 1][0] == caption_identifier[0][1]
        a[index_caption_identifier_in_a - 1].keys.first
      # if next element has type is the same as caption, move caption in him
      elsif a[index_caption_identifier_in_a + 1][0] == caption_identifier[0][1]
        a[index_caption_identifier_in_a + 1].keys.first
      end
    future_identifier = platform_post.identifier[future_identifier_index]

    text = @post.title.present? ? "<b>#{@post.title}</b>\n\n#{@post.text}" : @post.text.to_s
    markdown_text = @markdown.render(text)
    markdown_text = markdown_text.html_to_tg_markdown

    edit_media_caption(bot, future_identifier, markdown_text)
    future_identifier
  end

  def edit_media_caption(bot, identifier, text)
    media = { type: identifier['type'], media: identifier['file_id'], caption: text, parse_mode: 'html' } # photo type ???
    bot.edit_message_media({ chat_id: identifier['chat_id'],
                             message_id: identifier['message_id'],
                             media: media })
  # По-хорошему если нет аттачментов нужно преобразовать media сообщение в text, но так нельзя
  # поэтому caption удаляется если нет аттачментов
  rescue StandardError
    Rails.logger.error("Failed edit caption for telegram message at #{Time.now.utc.iso8601}")
  end

  def get_tg_bot(platform_post)
    bots_from_config = Telegram.bots_config.select { |_k, v| v == platform_post.channel.token }
    bots_hash = Telegram.bots.select { |k, _v| k == bots_from_config.first[0] }
    bots_hash.first[1]
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
end
