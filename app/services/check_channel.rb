# frozen_string_literal: true

class CheckChannel
  prepend SimpleCommand
  include TelegramShared

  attr_accessor :channel, :params

  def initialize(channel, params)
    @channel = channel
    @params = params
  end

  def call
    params[:channel][:platform] == 'telegram' ? check_telegram : check_matrix
  end

  def check_telegram
    errs = []
    options = {}
    token = params[:channel][:token]

    # when disable from settings
    if params[:channel][:enabled].present? && params[:channel][:enabled] == '0'
      bot = Twilight::Application::CURRENT_TG_BOTS.dig(token.to_s, :client)
      Platform::ManageTelegramPollers.call(bot, 'delete')
      return
    end

    existing_bot = Twilight::Application::CURRENT_TG_BOTS.dig(token.to_s, :client)
    bot =
      if existing_bot.present?
        existing_bot
      else
        Telegram::Bot::Client.new(token)
      end

    begin
      me = bot.get_me
    rescue Telegram::Bot::Error
      errs << 'Invalid bot token!'
      return errors.add(:base, errs)
    end

    errs << "Bot can't read group messages!" if me.dig('result', 'can_read_all_group_messages') != true

    options[:bot_id] = me['result']['id']

    begin
      chat = bot.get_chat(chat_id: params[:channel][:room])
    rescue Telegram::Bot::Error
      errs << 'Channel not available! (Not found or bot access problems?)'
    end

    begin
      bot.get_chat(chat_id: params[:channel][:room_attachments])
    rescue Telegram::Bot::Error
      errs << 'Attachments channel not available! (Not found or bot access problems?)'
    end

    errs << 'Channel ID == Attachment Channel ID' if params[:channel][:room] == params[:channel][:room_attachments]

    return errors.add(:base, errs) if errs.any?

    room_attachments = params[:channel][:room_attachments]
    author = params[:channel][:author]

    options[:room_attachments] = room_attachments if room_attachments.present?
    options[:author] = author if author.present?

    options[:notifications_enabled] = (params[:channel][:enable_notifications] == '1')
    options[:import_from_tg] = (params[:channel][:import_from_tg] == '1')

    # Comments

    comment_chat_id = chat.dig('result', 'linked_chat_id')
    options[:comments_enabled] = comment_chat_id.present?
    if comment_chat_id.present?
      comment_chat_id = chat.dig('result', 'linked_chat_id')

      begin
        comment_chat = bot.get_chat(chat_id: comment_chat_id)
      rescue Telegram::Bot::Error
        errs << 'Comments chat not available! (Not found or bot access problems?)'
        return errors.add(:base, errs) if errs.any?
      end

      unless comment_chat.dig('result', 'permissions',
                              'can_send_messages') || comment_chat.dig('result', 'permissions',
                                                                       'can_send_media_messages') || comment_chat.dig(
                                                                         'result', 'permissions', 'can_send_other_messages'
                                                                       )
        errs << "Bot don't have permissions to send messages!"
        return errors.add(:base, errs) if errs.any?
      end

      options[:linked_chat_id] = comment_chat_id
    end

    # Other

    options[:title] = chat['result']['title']
    options[:username] = chat['result']['username']
    options[:invite_link] = chat['result']['invite_link']

    avatar = get_chat_avatar(bot, params[:channel][:room])
    if avatar.present?
      if @channel.options&.dig('avatar_size').nil? ||
         (@channel.options['avatar_size'].present? && @channel.options['avatar_size'] != avatar[:file_size])
        file = URI.parse(avatar[:link]).open
        @channel.avatar.attach(io: file, filename: 'avatar.jpg', content_type: file.content_type)
      end
      options[:avatar_size] = avatar[:file_size]
    elsif avatar.nil? && @channel.avatar.present?
      # remove channel avatar
      options[:avatar_size] = 0
      @channel.avatar.purge
    else
      options[:avatar_size] = 0
    end

    @channel.options = options

    Platform::ManageTelegramPollers.call(bot, 'add') unless existing_bot.present?

    bot
  end

  def check_matrix
    server = params[:channel][:server] # default: https://matrix.org/_matrix/
    token = params[:channel][:token]
    errs = []

    options = { comments_enabled: false }

    return if params[:channel][:enabled].present? && params[:channel][:enabled] == '0' # when disable from settings

    # Server & access token validation
    begin
      method = 'account/whoami'
      info = Matrix.get(server, token, method, {})

      options[:user_id] = info['user_id'] if info['user_id'].present?

      errs << "#{info[:errcode]}: #{info[:error]}" if info[:errcode].present?
    rescue StandardError
      errs << 'Getting about me info failed! (wrong server or access token?)'
    end

    return errors.add(:base, errs) if errs.any?

    options[:server] = server

    # Check room state
    room = params[:channel][:room]
    method = "rooms/#{room}/state"
    info = Matrix.get(server, token, method, {})

    errs << "#{info['errcode']}: #{info['error']}" unless info.is_a?(Array)

    return errors.add(:base, errs) if errs.any?

    # Get chat name & avatar
    title = Matrix.get(server, token, "rooms/#{room}/state/m.room.name", {})
    options[:title] = title['name'] if title['name'].present?

    avatar_mx = Matrix.get(server, token, "rooms/#{room}/state/m.room.avatar", {})
    if avatar_mx['url'].present?
      avatar_server = avatar_mx['url'].split('/')[2]
      avatar_id = avatar_mx['url'].split('/')[3]

      avatar = Matrix.download(server, token, avatar_server, avatar_id, {})

      if @channel.options&.dig('avatar_size').nil? ||
         (@channel.options['avatar_size'].present? && @channel.options['avatar_size'] != avatar.size)
        file = avatar.open
        @channel.avatar.attach(io: file, filename: 'avatar.jpg', content_type: avatar.content_type)
      end
      options[:avatar_size] = avatar.size
    elsif avatar_mx['url'].nil? && @channel.avatar.present?
      options[:avatar_size] = 0
      @channel.avatar.purge
    else
      options[:avatar_size] = 0
    end

    #Channel URL (via matrix.to)
    options[:url] = "https://matrix.to/#/#{room}"

    @channel.options = options
  end
end
