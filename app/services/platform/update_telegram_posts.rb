# frozen_string_literal: true

class Platform::UpdateTelegramPosts
  prepend SimpleCommand

  attr_accessor :post, :params

  def initialize(post, params)
    @params = params
    @post = post

    @platform = Platform.find_by(title: 'telegram')

    @new_title = params[:post][:title]
    @new_text = params[:post][:content]

    @deleted_attachments = @params[:deleted_attachments]&.to_unsafe_h&.select { |_k, v| v == '0' }&.keys
    # need sort @deleted_attachments in the order of their posting platforms (grouping of pictures)
    @attachments = @post.content_attachments&.map { |att| att.blob.signed_id }
    @deleted_attachments = @attachments&.select { |att| att.in?(@deleted_attachments) }

    @markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, no_intra_emphasis: false, fenced_code_blocks: false,
                                                                 disable_indented_code_blocks: true, autolink: false,
                                                                 tables: false, underline: false, highlight: false)
  end

  def call
    delete_attachments if @deleted_attachments.present?

    old_text = @post.text.to_s

    old_max_first_post_length = @post.title.present? ? (4096 - "<b>#{@post.title}</b>\n\n".length) : 4096
    new_max_first_post_length = @new_title.present? ? (4096 - "<b>#{@new_title}</b>\n\n".length) : 4096

    old_post_text_blocks = text_blocks(old_text, old_max_first_post_length)
    new_post_text_blocks = text_blocks(@new_text, new_max_first_post_length)

    check_onlylink
    return if new_post_text_blocks.nil? && old_post_text_blocks.nil?

    # Something changed
    if ((new_post_text_blocks != old_post_text_blocks) || (@new_title.length != @post.title.length)) && check_caption
      return # false if no caption or new length > 1024 (to create contents)
    end

    # If, during caption check the new text length exceeded 1024 characters, then we deleted the content
    # So the old text also needs to be updated;
    if old_text != @post.text.to_s
      old_text = @post.text.to_s
      old_post_text_blocks = text_blocks(old_text, old_max_first_post_length)
    end

    if new_post_text_blocks.nil?
      options = post_options(@post)
      if options[:onlylink]
        @post.contents.where(has_attachments: false).delete_all
        return
      end
      degree_index = 0
      old_post_text_blocks.each_with_index do |_old_block, i|
        remove_content(i - degree_index)
        degree_index += 1
      end
    elsif old_post_text_blocks.nil?
      new_post_text_blocks.each_with_index { |new_block, i| add_content(new_block, i) if new_block.present? }
    elsif new_post_text_blocks.count >= old_post_text_blocks.count
      new_post_text_blocks.each_with_index do |new_block, i|
        next if (new_block == old_post_text_blocks[i]) && (@new_title == @post.title)

        update_content(new_block, i) if old_post_text_blocks[i].present?
        add_content(new_block, i) if old_post_text_blocks[i].nil?
      end
    elsif new_post_text_blocks.count < old_post_text_blocks.count
      degree_index = 0
      old_post_text_blocks.each_with_index do |old_block, i|
        degree_index += 1
        next if (old_block == new_post_text_blocks[i]) && (@new_title == @post.title)

        degree_index -= i if degree_index == i

        update_content(new_post_text_blocks[i], i) if new_post_text_blocks[i].present?
        remove_content(i - degree_index) if new_post_text_blocks[i].nil?
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

  def add_content(new_block, index)
    content = Content.create!(user: @post.user, post: @post, text: new_block)

    options = post_options(@post)
    return if options[:onlylink]

    @post.published_channels.where(platform: @platform).each do |channel|
      bot = get_tg_bot(channel)

      first_message = (index == 0)

      new_block = @markdown.render(new_block) if new_block.present?
      new_block = new_block.html_to_tg_markdown if new_block.present?
      new_block = "<b>#{@new_title}</b>\n\n#{new_block}" if first_message && @new_title.present? && new_block.present?

      @msg = bot.send_message({ chat_id: channel[:room],
                                text: new_block,
                                parse_mode: 'html',
                                disable_notification: !options[:enable_notifications] })

      PlatformPost.create!(
        identifier: { chat_id: @msg['result']['chat']['id'],
                      message_id: @msg['result']['message_id'],
                      options: options },
        platform: @platform,
        post: @post,
        content: content, channel_id: channel[:id]
      )
    end
  end

  def update_content(new_text, index)
    content = @post.contents.where(has_attachments: false).order(:id)[index]
    content.update!(text: new_text)

    options = post_options(@post)
    return if options[:onlylink]

    @post.platform_posts.where(content: content, platform: @platform).each do |platform_post|
      bot = get_tg_bot(platform_post)

      first_message = (index == 0)

      new_text = @markdown.render(new_text) if new_text.present?
      new_text = new_text.html_to_tg_markdown if new_text.present?
      new_text = "<b>#{@new_title}</b>\n\n#{new_text}" if first_message && @new_title.present? && new_text.present?

      bot.edit_message_text({ chat_id: platform_post.identifier['chat_id'],
                              message_id: platform_post.identifier['message_id'],
                              text: new_text,
                              parse_mode: 'html' })
    end
  end

  def check_onlylink
    options = post_options(@post)
    return false unless options[:onlylink]

    # It is assumed that the onlylink option will not have 2+ posts or 4096+ characters -
    # and there will be no extra post platforms, respectively;
    if @new_title != @post.title
      platform_posts = PlatformPost.where(post: @post, platform: @platform)
      platform_posts.each do |platform_post|
        bot = get_tg_bot(platform_post)
        update_onlylink(bot, platform_post)
      end
    end

    options[:onlylink]
  end

  def update_onlylink(bot, platform_post)
    post_link = "http://#{Rails.configuration.credentials[:host]}:#{Rails.configuration.credentials[:port]}/posts/#{@post.id}"
    full_post_link = "<a href=\"#{post_link}\">#{post_link}</a>"
    onlylink_text = @new_title.present? ? "<b>#{@new_title}</b>\n\n#{full_post_link}" : full_post_link

    bot.edit_message_text({ chat_id: platform_post.identifier['chat_id'],
                            message_id: platform_post.identifier['message_id'],
                            text: onlylink_text,
                            parse_mode: 'html' })
  end

  def check_caption
    content_with_att = @post.contents.select(&:has_attachments?)&.first
    has_platform_post_with_caption = false

    if content_with_att.present?
      platform_post_with_atts = PlatformPost.where(content: content_with_att,
                                                   platform: @platform)&.first
      if platform_post_with_atts.present?
        platform_post_with_atts.identifier.each do |ident|
          has_platform_post_with_caption = true if ident.dig('options', 'caption')
        end
      end
    end
    return false if has_platform_post_with_caption == false

    # Text is too long, remove caption and make contents
    if @new_title.length + @new_text.length > 1024
      @post.platform_posts.where(content: content_with_att, platform: @platform).each do |platform_post|
        ident_caption_index = nil
        bot = get_tg_bot(platform_post)

        platform_post.identifier.each_with_index do |ident, index|
          if ident.dig('options', 'caption')
            edit_media_caption(bot, ident, '')
            ident_caption_index = index
          end
        end

        next unless ident_caption_index.present?

        platform_post.identifier[ident_caption_index]['options'] =
          platform_post.identifier[ident_caption_index]['options'].merge(caption: false)
        platform_post.save!
      end
      # Remove all contents where is no platform posts (in caption case its all contents where is no attachments).
      # It eliminates next content creation errors. Not perfect solution but works.
      @post.contents.where(has_attachments: false).delete_all
      # Make contents, just run further
      false
    # Length looks good
    else
      # in call() method we make return, so here we must update text content
      update_content(@new_text, 0)

      text = @markdown.render(@new_text) if @new_text.present?
      text = text.html_to_tg_markdown if text.present?
      text = "<b>#{@new_title}</b>\n\n#{text}" if @new_title.present? && text.present?

      @post.platform_posts.where(content: content_with_att, platform: @platform).each do |platform_post|
        bot = get_tg_bot(platform_post)

        platform_post.identifier.each do |ident|
          edit_media_caption(bot, ident, text) if ident.dig('options', 'caption')
        end
      end
    end
  end

  def remove_content(index)
    content = @post.contents.where(has_attachments: false).order(:id)[index]

    platform_posts = @post.platform_posts.where(content: content, platform: @platform)

    Platform::DeleteTelegramPosts.call(platform_posts)
    PlatformPost.where(platform: platform_posts, post: @post).delete_all

    content.delete
  end

  def delete_attachments
    @post.platform_posts.joins(:content).where(platform: @platform,
                                               contents: { has_attachments: true }).each do |platform_post|
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
  # In an amicable way, if there are no attachments, you need to convert the media message to text, but this cannot be done
  # so the caption is removed if there are no attachments
  rescue StandardError
    Rails.logger.error("Failed edit caption for telegram message at #{Time.now.utc.iso8601}")
  end

  def post_options(post)
    # Get last platform post options if exists
    platform_post = post.platform_posts.select { |p| p.platform == @platform }&.last
    platform_identifier = platform_post&.identifier.is_a?(Array) ? platform_post&.identifier&.first : platform_post&.identifier
    platform_options = platform_identifier&.dig('options')

    notification = platform_options&.dig('enable_notifications') || false
    onlylink = platform_options&.dig('onlylink') || false
    { enable_notifications: notification, onlylink: onlylink, caption: false }
  end

  # PlatformPost or Channel support
  def get_tg_bot(object)
    object = object.channel if object.is_a?(PlatformPost)
    bots_from_config = Telegram.bots_config.select { |_k, v| v == object.token }
    bots_hash = Telegram.bots.select { |k, _v| k == bots_from_config.first[0] }
    bots_hash.first[1]
  end
end
