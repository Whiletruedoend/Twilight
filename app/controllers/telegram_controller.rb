# frozen_string_literal: true

# https://github.com/telegram-bot-rb/telegram-bot#controller
class TelegramController < Telegram::Bot::UpdatesController
  include TelegramShared

  def initialize(bot = nil, update = nil)
    @telegram_platform = Platform.find_by(title: 'telegram')
    @channel_ids = Channel.where(enabled: true, platform: @telegram_platform).map{ |ch| [ch.id, ch.room]}.to_h
    @linked_group_channels_ids = Channel.where(id: @channel_ids.keys).map{ |ch| [ch.id, ch.options.dig("linked_chat_id")] }.to_h.compact_blank

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
    super
  end

  def message(message)
    check_message(message)
    # message can be also accessed via instance method
    message == payload # true
    # store_message(message['text'])
  end

  def edited_message(message)
    check_edit_message(message)
    # message can be also accessed via instance method
    message == payload # true
    # store_message(message['text'])
  end

  def check_message(message)
    comment_channel = message.dig('reply_to_message', 'sender_chat', 'id')
    from_channel = message.dig('sender_chat', 'id')

    if from_channel.present? && @channel_ids.values.include?(from_channel.to_s)
      channel = Channel.find_by(room: from_channel)
      check_linked_group(message, channel) 
      check_platform_message(message, channel)
    end
    return check_platform_comment(message) if comment_channel.present? && @channel_ids.values.include?(comment_channel.to_s)

    reply_message = message.dig('reply_to_message', 'message_id') # Check reply on chat comment
    check_reply_comment(message, reply_message) if reply_message.present?
  end

  ######### Import info from channel #########

  # Autocall when post
  def channel_post(message)
    from_channel = message.dig('sender_chat', 'id')
    return if !from_channel.present? && !@channel_ids.values.include?(from_channel.to_s)
    channel = Channel.find_by(room: from_channel)

    if message.dig('new_chat_photo').present?
      return new_chat_photo(message, channel, from_channel)
    end
    if message.dig('delete_chat_photo').present? && message.dig('delete_chat_photo')
      return delete_chat_photo(channel)
    end

    import_option = channel.options.dig("import_from_tg", "enabled")
    import_from_tg(message, channel, from_channel) if import_option.present? && import_option
  end

  def import_from_tg(message, channel, from_channel)
    Rails.logger.debug('TG: POSTING FROM TG DETECTED!'.green) if Rails.env.development?
    attachment = check_attachments(message)

    if attachment.present?
      import_from_tg_withatt(message, channel, from_channel, attachment)
    else
      import_from_tg_noatt(message, channel, from_channel)
    end
  end

  def import_from_tg_withatt(message, channel, from_channel, attachment)
    blog_platform = Platform.find_by(title: 'blog')
    caption = message.dig('caption')
    caption_entities = attachment.dig(:caption_entities)
    title = caption_entities.present? ? get_post_title(caption_entities, caption) : nil

    caption = caption[title.length..caption.length] if title.present?

    date = message.dig('date')
    existing_pp = get_existing_pp(channel, date)
    if existing_pp.present?
      Rails.logger.debug('TG: EXISTING POST WITH ATTACHMENTS FOUND!'.green) if Rails.env.development?
      post = existing_pp.post
      content = post.contents.find{ |c| c.has_attachments == true }
      if content.nil?
        # For blog platform
        Content.create!(text: caption, post: post, user: channel.user, has_attachments: true, platform: blog_platform)
        # For tg
        content = Content.create!(text: caption, post: post, user: channel.user, has_attachments: true, platform: channel.platform)
      end
    else
      Rails.logger.debug('TG: NEW POST WITH ATTACHMENTS'.green) if Rails.env.development?
      is_hidden = channel.options.dig("import_from_tg", "hide_by_default")
      is_hidden = is_hidden.present? && is_hidden
      post = Post.create!(title: title, user: channel.user, privacy: 0, is_hidden: is_hidden)
      caption = caption.lstrip if caption.present?

      # For blog platform
      Content.create!(text: caption, post: post, user: channel.user, has_attachments: true, platform: blog_platform)
      # For tg
      content = Content.create!(text: caption, post: post, user: channel.user, has_attachments: true, platform: channel.platform)
    end

    options = { "enable_notifications": true, "onlylink": false, "caption": caption.present? }
    file = URI.parse(attachment[:link]).open
    post.attachments.attach(io: file, filename: attachment[:file_name], content_type: file.content_type)
    att = post.attachments.find{ |att| att.byte_size == attachment[:file_size] }
    blob_signed_id = att.signed_id

    identifier = { chat_id: message['chat']['id'],
                   message_id: message['message_id'],
                   file_id: attachment[:file_id],
                   type: get_attachment_type(att),
                   blob_signed_id: blob_signed_id,
                   date: message['date'],
                   options: options
                }
    
    if existing_pp.present?
      existing_pp_identifier = existing_pp.identifier
      if existing_pp_identifier.is_a?(Array)
        existing_pp_identifier.append(identifier)
        existing_pp.update!(identifier: existing_pp_identifier)
      #elsif existing_pp_identifier.is_a?(Hash)
      #  print("EXISTING PP ID: #{existing_pp.id}\n".red)
      end
    else
      platform_post = PlatformPost.create!(identifier: [identifier], platform: channel.platform,
                                           post: post, content: content, channel_id: channel.id)
    end
  end

  def import_from_tg_noatt(message, channel, from_channel)
    blog_platform = Platform.find_by(title: 'blog')
    text = message.dig("text")
    entities = message.dig("entities")
    title = entities.present? ? get_post_title(entities, text) : nil

    text = text[title.length..text.length] if title.present?

    date = message.dig('date')
    existing_pp = get_existing_pp(channel, date)
    if existing_pp.present?
      Rails.logger.debug('TG: EXISTING POST FOUND!'.green) if Rails.env.development?
      post = existing_pp.post
    else
      Rails.logger.debug('TG: NEW POST'.green) if Rails.env.development?
      is_hidden = channel.options.dig("import_from_tg", "hide_by_default")
      is_hidden = is_hidden.present? && is_hidden
      post = Post.create!(title: title, user: channel.user, privacy: 0, is_hidden: is_hidden)
      text = text.lstrip if text.present?
    end

    # For blog platform
    Content.create!(text: text, post: post, user: channel.user, has_attachments: false, platform: blog_platform)
    # For tg
    content = Content.create!(text: text, post: post, user: channel.user, has_attachments: false, platform: channel.platform)
    options = { "enable_notifications": true, "onlylink": false, "caption": false }

    message_id = message.dig('message_id')
    identifier = { chat_id: from_channel, message_id: message_id, options: options, date: date }
    platform_post = PlatformPost.create!(identifier: identifier, platform: channel.platform,
                                         post: post, content: content, channel_id: channel.id)
  end

  def get_existing_pp(channel, date)
    PlatformPost.where(channel: channel).find do |pp|
      if pp.identifier&.is_a?(Array)
        pp.identifier&.find{ |ppp| ppp["date"] == date }
      elsif pp.identifier&.is_a?(Hash)
        pp.identifier&.dig('date') == date
      end
    end
  end

  def get_existing_pp_by_msg(channel, chat_id, message_id)
    PlatformPost.where(channel: channel).find do |pp|
      if pp.identifier&.is_a?(Array)
        pp.identifier&.find{ |ppp| ppp["chat_id"] == chat_id && ppp["message_id"] == message_id }
      elsif pp.identifier&.is_a?(Hash)
        pp.identifier&.dig('chat_id') == chat_id && pp.identifier&.dig('message_id') == message_id
      end
    end
  end

  def get_post_title(entities, text)
    bold_entry = entities.find{ |e| e["type"] == "bold" }
    return nil if bold_entry.nil? || bold_entry["offset"] != 0
    Rails.logger.debug('TG: POST TITLE FOUND!'.green) if Rails.env.development?
    text[bold_entry["offset"]..bold_entry["length"]]
  end

  def new_chat_photo(message, channel, from_channel)
    Rails.logger.debug('TG: NEW CHANNEL PHOTO...'.green) if Rails.env.development?
    new_photo = message.dig('new_chat_photo').last
    options = channel.options

    if new_photo["avatar_size"] != options["avatar_size"]
      options["avatar_size"] = new_photo["file_size"]
      avatar = get_chat_avatar(bot, from_channel)

      channel.avatar.purge if channel.avatar.present? && avatar.present?
      file = URI.parse(avatar[:link]).open if avatar.present?
      
      channel.avatar.attach(io: file, filename: 'avatar.jpg', content_type: file.content_type) if avatar.present?
      channel.update!(options: options)
    end
  end

  def delete_chat_photo(channel)
    Rails.logger.debug('TG: CHANNEL PHOTO DELETE...'.green) if Rails.env.development?
    channel.avatar.purge if channel.avatar.present?
    options = channel.options
    options["avatar_size"] = 0
    channel.update!(options: options)
  end

  ######### Group linking #########

  def check_linked_group(message, channel)
    linked_chat_id = channel.options.dig('linked_chat_id')
    return if linked_chat_id.present?
    options = channel.options
    options["linked_chat_id"] = message["chat"]["id"]
    options["comments_enabled"] = true
    channel.update!(options: options)
  end

  def check_platform_message(message, channel)
    Rails.logger.debug('TG: CHECKING POST FOR LINKED CHAT...'.green) if Rails.env.development?
    chat_id = message.dig('sender_chat', 'id')
    message_id = message.dig('forward_from_message_id')
    existing_pp = get_existing_pp_by_msg(channel, chat_id, message_id)
    return if existing_pp.nil?
    Rails.logger.debug('TG: LINKED CHAT FOR POST FOUND!'.green) if Rails.env.development?
    identifier = existing_pp.identifier
    if identifier.is_a?(Array)
      identifier = identifier.each { |ii| ii.merge!("linked_chat_message_id" => message.dig('message_id')) }
    elsif identifier.is_a?(Hash)
      identifier["linked_chat_message_id"] = message.dig('message_id')
    end
    existing_pp.update!(identifier: identifier)
  end

  ######### Comments #########

  def check_edit_message(message)
    comment_channel = message.dig('reply_to_message', 'sender_chat', 'id')

    return check_edit_platform_comment(message) if comment_channel.present? && @channel_ids.values.include?(comment_channel.to_s)

    reply_message = message.dig('reply_to_message', 'message_id') # Check reply on chat comment
    check_edit_reply_comment(message, reply_message) if reply_message.present?
  end

  def check_platform_comment(message)
    Rails.logger.debug('TG: ADDING COMMENT...'.green) if Rails.env.development?
    post_message_id = message['reply_to_message']['forward_from_message_id']

    platform_post = nil

    PlatformPost.where(channel: @channel_ids.keys).each do |p_post|
      if p_post[:identifier].is_a?(Array) # Post has attachments
        p_post[:identifier].each do |p|
          platform_post = p_post if p['message_id'] == post_message_id && p_post.platform_id == @telegram_platform.id
        end
      elsif p_post[:identifier]['message_id'] == post_message_id
        platform_post = p_post
      end
    end

    create_comment(message, platform_post) if platform_post.present?
  end

  def check_edit_platform_comment(message)
    Rails.logger.debug('TG: CHECK EDITING COMMENT...'.green) if Rails.env.development?
    post_message_id = message['message_id']
    comment = nil
    Comment.where(platform: @telegram_platform).each do |p|
      if p[:identifier].is_a?(Array) # Comment has attachments
        p[:identifier].each { |c| comment = p if c['message_id'] == post_message_id }
      elsif p[:identifier]['message_id'] == post_message_id
        comment = p
      end
    end

    edit_comment(message, comment) if comment.present?
  end

  def check_reply_comment(message, reply_message)
    Rails.logger.debug('TG: CHECK REPLY COMMMENT...'.green) if Rails.env.development?

    platform_post = nil
    
    Comment.where(platform: @telegram_platform).each do |p_post|
      next if p_post[:identifier].nil? # Blog comment
      if p_post[:identifier].is_a?(Array) # Post has attachments
        p_post[:identifier].each do |p|
          platform_post = p_post if p['message_id'] == reply_message #&& p_post.platform_user.platform_id == @telegram_platform.id
        end
      elsif p_post[:identifier]['message_id'] == reply_message #&& p_post.platform_user.platform_id == @telegram_platform.id
        platform_post = p_post
      end
    end

    create_comment(message, platform_post) if platform_post.present?
  end

  def check_edit_reply_comment(message, reply_message)
    Rails.logger.debug('TG: CHECK REPLY EDITING COMMMENT...'.green) if Rails.env.development?

    prev_comment = nil
    current_comment = nil

    Comment.where(platform: @telegram_platform).each do |p|
      if p[:identifier].is_a?(Array) # Comment has attachments
        p[:identifier].each do |c|
          prev_comment = p if c['message_id'] == reply_message
          current_comment = p if c['message_id'] == message['message_id']
        end
      else
        prev_comment = p if p[:identifier]['message_id'] == reply_message
        current_comment = p if p[:identifier]['message_id'] == message['message_id']
      end
    end

    edit_comment(message, current_comment) if prev_comment.present? && current_comment.present?
  end

  def create_comment(message, platform_post)
    user = check_user(message)

    attachment = check_attachments(message)
    channel_id = @channel_ids.find { |k,v| v == message.dig('reply_to_message', 'chat', 'id').to_s }&.first # old: sender_chat
    channel_id = @linked_group_channels_ids.find { |k,v| v == message.dig('reply_to_message', 'chat', 'id') }&.first if channel_id.nil? # old: sender_chat

    if attachment.present?
      create_attachment_comment(message, attachment, user, platform_post, channel_id)
    else
      comment_text = message['text']
      identifier = { message_id: message['message_id'], chat_id: message['chat']['id'], date: message['date'] }
      Comment.create!(identifier: identifier, text: comment_text, post: platform_post.post, platform_user: user,
                      channel_id: channel_id, platform: @telegram_platform, 
                      parent_id: (platform_post.is_a?(Comment) ? platform_post.id : nil))
      Rails.logger.debug('TG: COMMENT ADDED!'.green) if Rails.env.development?
    end
  end

  def create_attachment_comment(message, attachment, user, platform_post, channel_id)
    identifier = { message_id: message['message_id'],
                   chat_id: message['chat']['id'],
                   file_id: attachment[:file_id],
                   file_size: attachment[:file_size],
                   date: message['date'] }
    if attachment[:media_group_id].present?
      Rails.logger.debug("MEDIA GROUP ID PRESENT... #{attachment[:media_group_id]}".green) if Rails.env.development?
      # puts(attachment)
      # Find comment by media_group_id and att attachment if found
      media_comment = []
      Comment.where(platform: @telegram_platform).each do |comm|
        if comm[:identifier].is_a?(Array) # Comment has attachments
          comm[:identifier].each do |c|
            media_comment = comm if c['media_group_id'] == attachment[:media_group_id].to_s
          end
        elsif comm[:identifier]['media_group_id'] == attachment[:media_group_id].to_s
          media_comment = comm
        end
      end
      Rails.logger.debug('MEDIA COMMENT CHECK...'.green) if Rails.env.development?
      if media_comment.present? # Already exists, update comment...
        media_array = []
        # P.S. Only first array element contains media_group_id
        if media_comment.identifier.is_a?(Array)
          media_comment.identifier.each { |media| media_array.append(media) }
        else
          media_array.append(media_comment.identifier)
        end
        media_array.append(identifier)
        media_comment.identifier = media_array
        media_comment.text = attachment[:caption] if attachment[:caption] != media_comment.text && attachment[:caption].present?
        file = URI.parse(attachment[:link]).open
        media_comment.attachments.attach(io: file, filename: attachment[:file_name], content_type: file.content_type)
        media_comment.save!
        return
      else
        identifier[:media_group_id] = attachment[:media_group_id].to_s
      end
    end
    text = attachment[:caption].present? ? attachment[:caption] : ""
    comment = Comment.create!(identifier: identifier, text: text, post: platform_post.post,
                              platform_user: user, has_attachments: true, channel_id: channel_id,
                              platform: @telegram_platform, parent_id: (platform_post.is_a?(Comment) ? platform_post.id : nil))
    file = URI.parse(attachment[:link]).open
    comment.attachments.attach(io: file, filename: attachment[:file_name], content_type: file.content_type)
    Rails.logger.debug('TG: COMMENT WITH ATTACHMENT ADDED!'.green) if Rails.env.development?
  end

  def edit_comment(message, comment)
    check_user(message)
    attachment = check_attachments(message)
    if attachment.present?
      identifier = { message_id: message['message_id'],
                     chat_id: message['chat']['id'],
                     date: message['date'],
                     file_id: attachment[:file_id],
                     file_size: attachment[:file_size] }
      att_id = nil

      if comment[:identifier].is_a?(Array)
        comment[:identifier].each_with_index do |c, i|
          next unless (c['message_id'] == message['message_id']) && (c['file_size'] != attachment[:file_size])
          Rails.logger.debug('FOUND YA IN ARRAY!'.green) if Rails.env.development?
          # delete(e) # Sync attachment deletion
          # c.append(identifier)
          c.clear
          c.merge!(identifier)
          att_id = j
        end
      else
        if (comment[:identifier]['message_id'] == message['message_id']) && (comment[:identifier]['file_size'] != attachment[:file_size])
          Rails.logger.debug('FOUND YA IN HASH!'.green) if Rails.env.development?
          comment[:identifier].clear
          comment[:identifier].merge!(identifier)
          att_id = i
        end
      end

      ActiveStorage::Attachment.where(record_type: 'Comment', record: comment)[att_id].delete if att_id.present?
      file = URI.parse(attachment[:link]).open if att_id.present?
      if att_id.present?
        comment.attachments.attach(io: file, filename: attachment[:file_name],
                                   content_type: file.content_type)
      end
      comment_text = message['caption']
      comment.update!(text: comment_text, is_edited: true)
      Rails.logger.debug('TG: COMMENT WITH ATTACHMENTS UPDATED!'.green) if Rails.env.development?
    else
      comment_text = message['text']
      comment.update!(text: comment_text, is_edited: true)
      Rails.logger.debug('TG: COMMENT UPDATED!'.green) if Rails.env.development?
    end
  end

  ######### PlatformUser && Other #########

  def check_user(message)
    tg_user = message['from']['id']

    if tg_user == 1_087_968_824 # Anonymous group bot, replace name&avatar from channel
      tg_user = message['chat']['id']
      tg_fname = message['chat']['title']
      tg_lname = nil
      tg_username = message['chat']['username'] # @uname
      avatar = get_chat_avatar(bot, tg_user)
    else
      tg_fname = message['from']['first_name']
      tg_lname = message['from']['last_name']
      tg_username = message['from']['username'] # @uname
      avatar = get_avatar(tg_user)
    end

    user =
      PlatformUser.find do |usr|
        usr[:identifier]['id'] == tg_user && usr.platform_id == @telegram_platform.id
      end

    if user.present?
      Rails.logger.debug('TG: USER FOUND'.green) if Rails.env.development?
      old_identifier = user.identifier
      identifier = { id: tg_user, fname: tg_fname, lname: tg_lname, username: tg_username }
      identifier[:avatar_size] = avatar[:file_size] if avatar.present?

      if old_identifier['avatar_size'] != identifier[:avatar_size] # Update user avatar
        user.avatar.purge if user.avatar.present?
        file = URI.parse(avatar[:link]).open if avatar.present?
        user.avatar.attach(io: file, filename: 'avatar.jpg', content_type: file.content_type) if avatar.present?
      end

      user.update!(identifier: identifier) unless old_identifier == identifier # Update user info
    else
      Rails.logger.debug('TG: USER NOT FOUND, CREATING...'.green) if Rails.env.development?
      identifier =
        { id: tg_user, fname: tg_fname, lname: tg_lname, username: tg_username }.compact
      user = PlatformUser.create!(identifier: identifier, platform: @telegram_platform)
      if avatar.present?
        file = URI.parse(avatar[:link]).open
        user.avatar.attach(io: file, filename: 'avatar.jpg', content_type: file.content_type)
        user.identifier[:avatar_size] = avatar[:file_size]
        user.save!
      end
    end
    user
  end

  def get_avatar(tg_user)
    begin
      photos_msg = bot.get_user_profile_photos(user_id: tg_user)
    rescue StandardError
      photos_msg = nil
    end

    return nil unless photos_msg.present? && photos_msg['result']['total_count'] >= 1

    photo = photos_msg['result']['photos'].first[0]
    file_id = photo['file_id']
    file_path = bot.get_file(file_id: file_id)['result']['file_path']
    { link: "https://api.telegram.org/file/bot#{bot.token}/#{file_path}", file_size: photo['file_size'] }
  end

  def check_attachments(message)
    Rails.logger.debug('CHECKING ATTACHMENTS...'.green) if Rails.env.development?
    if message.key?('photo')
      file_id = message['photo'].last['file_id']
    elsif message.key?('video')
      file_id = message['video']['file_id']
    elsif message.key?('audio')
      file_id = message['audio']['file_id']
    elsif message.key?('document')
      file_id = message['document']['file_id']
    end

    return nil if file_id.nil?

    Rails.logger.debug('TG: ATTACHMENT FOUND!'.green) if Rails.env.development?
    msg = bot.get_file(file_id: file_id)

    { link: "https://api.telegram.org/file/bot#{bot.token}/#{msg['result']['file_path']}",
      caption: message['caption'],
      caption_entities: message.dig('caption_entities'),
      file_id: file_id,
      file_size: msg['result']['file_size'],
      file_name: msg['result']['file_path'].split('/').last,
      media_group_id: message['media_group_id'],
      date: message['date'] }
  end

  def get_attachment_type(att)
    if @images.include?(att.content_type)
      'photo'
    elsif @videos.include?(att.content_type)
      'video'
    elsif @audios.include?(att.content_type)
      'audio'
    else
      'document'
    end
  end
end
