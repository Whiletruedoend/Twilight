# frozen_string_literal: true

# https://github.com/telegram-bot-rb/telegram-bot#controller
class TelegramController < Telegram::Bot::UpdatesController
  include TelegramShared

  def initialize(bot = nil, update = nil)
    @telegram_platform = Platform.find_by(title: 'telegram')
    @channel_ids = Channel.where(enabled: true, platform: @telegram_platform).map{ |ch| [ch.id, ch.room]}.to_h
    @linked_group_channels_ids = Channel.where(id: @channel_ids.keys).map{ |ch| [ch.id, ch.options.dig("linked_chat_id")] }.to_h.compact_blank
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

  def check_linked_group(message, channel)
    linked_chat_id = channel.options.dig('linked_chat_id')
    return if linked_chat_id.present?
    options = channel.options
    options["linked_chat_id"] = message["chat"]["id"]
    options["comments_enabled"] = true
    channel.update!(options: options)
  end

  def check_platform_message(message, channel)
    chat_id = message.dig('sender_chat', 'id')
    message_id = message.dig('forward_from_message_id')
    platform_post = PlatformPost.where(channel: channel).find{ |pp| pp.identifier["chat_id"] == chat_id && pp.identifier["message_id"] == message_id }
    identifier = platform_post.identifier
    identifier["linked_chat_message_id"] = message.dig('message_id')
    platform_post.update!(identifier: identifier)
  end

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
    channel_id = @channel_ids.find { |k,v| v == message.dig('reply_to_message', 'sender_chat', 'id').to_s }&.first
    channel_id = @linked_group_channels_ids.find { |k,v| v == message.dig('reply_to_message', 'sender_chat', 'id') }&.first if channel_id.nil?
    if attachment.present?
      create_attachment_comment(message, attachment, user, platform_post, channel_id)
    else
      comment_text = message['text']
      identifier = { message_id: message['message_id'], chat_id: message['chat']['id'] }
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
                   file_size: attachment[:file_size] }
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
      file_id: file_id,
      file_size: msg['result']['file_size'],
      file_name: msg['result']['file_path'].split('/').last,
      media_group_id: message['media_group_id'] }
  end
end
