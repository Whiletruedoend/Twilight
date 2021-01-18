# https://github.com/telegram-bot-rb/telegram-bot#controller
class TelegramController < Telegram::Bot::UpdatesController

  def initialize(bot = nil, update = nil)
    @channel_ids = Rails.configuration.credentials[:telegram][:channel_ids]
    @telegram_platform = Platform.find_by_title("telegram")
    super
  end

  def message(message)
    check_message(message)
    # message can be also accessed via instance method
    message == self.payload # true
    # store_message(message['text'])
  end

  def edited_message(message)
    check_edit_message(message)
    # message can be also accessed via instance method
    message == self.payload # true
    # store_message(message['text'])
  end

  def check_message(message)
    comment_channel = message.dig("reply_to_message","sender_chat","id")

    return check_platform_comment(message) if comment_channel.present? && @channel_ids.include?(comment_channel.to_s)
    reply_message = message.dig("reply_to_message","message_id") # Check reply on chat comment
    check_reply_comment(message, reply_message) if reply_message.present?
  end

  def check_edit_message(message)
    comment_channel = message.dig("reply_to_message","sender_chat","id")

    return check_edit_platform_comment(message) if comment_channel.present? && @channel_ids.include?(comment_channel.to_s)
    reply_message = message.dig("reply_to_message","message_id") # Check reply on chat comment
    check_edit_reply_comment(message, reply_message) if reply_message.present?
  end

  def check_platform_comment(message)
    puts("TG: ADDING COMMENT...".red) if Rails.env.development?
    post_message_id = message["reply_to_message"]["forward_from_message_id"]

    platform_post = nil

    PlatformPost.all.each do |p_post|
      if p_post[:identifier].is_a?(Array) # Post has attachments
        p_post[:identifier].each { |p| platform_post = p_post if p["message_id"] == post_message_id && p_post.platform_id == @telegram_platform.id }
      else
        platform_post = p_post if p_post[:identifier]["message_id"] == post_message_id && p_post.platform_id == @telegram_platform.id
      end
    end

    create_comment(message, platform_post) if platform_post.present?
  end

  def check_edit_platform_comment(message)
    puts("TG: CHECK EDITING COMMENT...".red) if Rails.env.development?
    post_message_id = message["message_id"]
    comment = nil
    Comment.all.each do |p|
      if p[:identifier].is_a?(Array) # Comment has attachments
        p[:identifier].each { |c| comment = p if c["message_id"] == post_message_id }
      else
        comment = p if p[:identifier]["message_id"] == post_message_id
      end
    end

    edit_comment(message, comment) if comment.present?
  end

  def check_reply_comment(message, reply_message)
    puts("TG: CHECK REPLY COMMMENT...".red) if Rails.env.development?

    platform_post = nil

    Comment.all.each do |p_post|
      if p_post[:identifier].is_a?(Array) # Post has attachments
        p_post[:identifier].each { |p| platform_post = p_post if p["message_id"] == reply_message && p_post.platform_user.platform_id == @telegram_platform.id }
      else
        platform_post = p_post if p_post[:identifier]["message_id"] == reply_message && p_post.platform_user.platform_id == @telegram_platform.id
      end
    end

    create_comment(message, platform_post) if platform_post.present?
  end

  def check_edit_reply_comment(message, reply_message)
    puts("TG: CHECK REPLY EDITING COMMMENT...".red) if Rails.env.development?

    prev_comment = nil
    current_comment = nil

    Comment.all.each do |p|
      if p[:identifier].is_a?(Array) # Comment has attachments
        p[:identifier].each do |c|
          prev_comment = p if c["message_id"] == reply_message
          current_comment = p if c["message_id"] == message["message_id"]
        end
      else
        prev_comment = p if p[:identifier]["message_id"] == reply_message
        current_comment = p if p[:identifier]["message_id"] == message["message_id"]
      end
    end

    edit_comment(message, current_comment) if prev_comment.present? && current_comment.present?
  end

  def create_comment(message, platform_post)
    user = check_user(message)

    attachment = check_attachments(message)
    if attachment.present?
      identifier = { :message_id => message["message_id"], :chat_id => message["chat"]["id"], :file_id => attachment[:file_id], :file_size => attachment[:file_size] }
      if attachment[:media_group_id].present?
        puts("MEDIA GROUP ID PRESENT... #{attachment[:media_group_id]}".red) if Rails.env.development?
        #puts(attachment)
        # Find comment by media_group_id and att attachment if found
        media_comment = []
        Comment.all.each do |comm|
          if comm[:identifier].is_a?(Array) # Comment has attachments
            comm[:identifier].each { |c| media_comment = comm if c["media_group_id"] == attachment[:media_group_id].to_s }
          else
            media_comment = comm if comm[:identifier]["media_group_id"] == attachment[:media_group_id].to_s
          end
        end
        puts("MEDIA COMMENT CHECK...".red)  if Rails.env.development?
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
          identifier.merge!(:media_group_id => attachment[:media_group_id].to_s )
        end
      end
      comment = Comment.create!(identifier: identifier, text: attachment[:caption], post: platform_post.post, platform_user: user, has_attachments: true)
      file = URI.parse(attachment[:link]).open
      comment.attachments.attach(io: file, filename: attachment[:file_name], content_type: file.content_type)
      puts("TG: COMMENT WITH ATTACHMENT ADDED!".red) if Rails.env.development?
    else
      comment_text = message["text"]
      identifier = { :message_id => message["message_id"], :chat_id => message["chat"]["id"] }
      Comment.create!(identifier: identifier, text: comment_text, post: platform_post.post, platform_user: user)
      puts("TG: COMMENT ADDED!".red) if Rails.env.development?
    end
  end

  def edit_comment(message, comment)
    check_user(message)
    attachment = check_attachments(message)
    if attachment.present?
      identifier = { :message_id => message["message_id"], :chat_id => message["chat"]["id"], :file_id => attachment[:file_id], :file_size => attachment[:file_size] }
      att_id = nil

      comment[:identifier].each_with_index do |c, i|
        if c.is_a?(Array)
          c.each_with_index do |e, j|
            if (e["message_id"] == message["message_id"]) && (c["file_size"] != attachment[:file_size])
              puts("FOUND YA IN ARRAY!".red) if Rails.env.development?
              #delete(e) # Sync attachment deletion
              #c.append(identifier)
              e.clear
              e.merge!(identifier)
              att_id = j
            end
          end
        else
          if (c["message_id"] == message["message_id"]) && (c["file_size"] != attachment[:file_size])
            puts("FOUND YA IN HASH!".red) if Rails.env.development?
            c.clear
            c.merge!(identifier)
            att_id = i
          end
        end
      end

      ActiveStorage::Attachment.where(record_type: "Comment", record: comment)[att_id].delete if att_id.present?
      file = URI.parse(attachment[:link]).open if att_id.present?
      comment.attachments.attach(io: file, filename: attachment[:file_name], content_type: file.content_type) if att_id.present?
      comment_text = message["caption"]
      comment.update!(text: comment_text, is_edited: true)
      puts("TG: COMMENT WITH ATTACHMENTS UPDATED!".red) if Rails.env.development?
    else
      comment_text = message["text"]
      comment.update!(text: comment_text, is_edited: true)
      puts("TG: COMMENT UPDATED!".red) if Rails.env.development?
    end
  end

  def check_user(message)
    tg_user = message["from"]["id"]

    if tg_user == 1087968824 # Anonymous group bot, replace name&avatar from channel
      tg_user = message["chat"]["id"]
      tg_fname = message["chat"]["title"]
      tg_lname = nil
      tg_username = message["chat"]["username"] # @uname
      avatar = get_chat_avatar(tg_user)
    else
      tg_fname = message["from"]["first_name"]
      tg_lname = message["from"]["last_name"]
      tg_username = message["from"]["username"] # @uname
      avatar = get_avatar(tg_user)
    end

    user = PlatformUser.select{ |usr| usr[:identifier]["id"] == tg_user && usr.platform_id == @telegram_platform.id }.first

    if user.present?
      puts("TG: USER FOUND".red) if Rails.env.development?
      old_identifier = user.identifier
      identifier = { :id=>tg_user, :fname=>tg_fname, :lname=>tg_lname, :username=> tg_username }
      identifier.merge!(:avatar_size=>avatar[:file_size]) if avatar.present?

      if old_identifier["avatar_size"] != identifier[:avatar_size] # Update user avatar
        user.avatar.purge if user.avatar.present?
        file = URI.parse(avatar[:link]).open if avatar.present?
        user.avatar.attach(io: file, filename: "avatar.jpg", content_type: file.content_type) if avatar.present?
      end

      user.update!(identifier: identifier) unless old_identifier == identifier # Update user info
    else
      puts("TG: USER NOT FOUND, CREATING...".red) if Rails.env.development?
      identifier = { :id=>tg_user, :fname=>tg_fname, :lname=>tg_lname, :username=> tg_username }.reject { |k,v| v.nil? }
      user = PlatformUser.create!(identifier: identifier, platform: @telegram_platform)
      if avatar.present?
        file = URI.parse(avatar[:link]).open
        user.avatar.attach(io: file, filename: "avatar.jpg", content_type: file.content_type)
        user.identifier.merge!(:avatar_size=>avatar[:file_size])
        user.save!
      end
    end
    user
  end

  def get_avatar(tg_user)
    begin
      photos_msg = Telegram.bot.get_user_profile_photos(user_id: tg_user)
    rescue
      photos_msg = nil
    end
    if photos_msg.present? && photos_msg["result"]["total_count"] >= 1
      photo = photos_msg["result"]["photos"].first[0]
      file_id = photo["file_id"]
      file_path = Telegram.bot.get_file(file_id: file_id)["result"]["file_path"]
      { link: "https://api.telegram.org/file/bot#{Telegram.bot.token}/#{file_path}", file_size: photo["file_size"] }
    else
      nil
    end
  end

  def get_chat_avatar(chat_id)
    begin
      photo_msg = Telegram.bot.get_chat(chat_id: chat_id)
    rescue
      photo_msg = nil
    end
    if photo_msg.present? && photo_msg["result"]["photo"].present?
      photo = photo_msg["result"]["photo"]
      file_id = photo["big_file_id"]
      file_path = Telegram.bot.get_file(file_id: file_id)["result"]["file_path"]
      { link: "https://api.telegram.org/file/bot#{Telegram.bot.token}/#{file_path}", file_size: "1" } # lol
    else
      nil
    end
  end

  def check_attachments(message)
    puts("CHECKING ATTACHMENTS...".red) if Rails.env.development?
    if message.has_key?("photo")
      file_id = message["photo"].last["file_id"]
    elsif message.has_key?("video")
      file_id = message["video"]["file_id"]
    elsif message.has_key?("audio")
      file_id = message["audio"]["file_id"]
    elsif message.has_key?("document")
      file_id = message["document"]["file_id"]
    end

    return nil if file_id.nil?
    puts("TG: ATTACHMENT FOUND!".red) if Rails.env.development?
    msg = Telegram.bot.get_file(file_id: file_id)

    { :link => "https://api.telegram.org/file/bot#{Telegram.bot.token}/#{msg["result"]["file_path"]}", :caption => message["caption"], :file_id => file_id, :file_size => msg["result"]["file_size"], :file_name => msg["result"]["file_path"].split('/').last, :media_group_id => message["media_group_id"] }
  end
end