# frozen_string_literal: true

module TelegramShared
  extend ActiveSupport::Concern

  def get_chat_avatar(bot, chat_id)
    begin
      photo_msg = bot.get_chat(chat_id: chat_id)
    rescue StandardError
      photo_msg = nil
    end

    return unless photo_msg.present? && photo_msg['result']['photo'].present?

    photo = photo_msg['result']['photo']
    file_id = photo['big_file_id']
    file_msg = bot.get_file(file_id: file_id)
    file_path = file_msg['result']['file_path']
    file_size = file_msg['result']['file_size'] || '1'
    { link: "https://api.telegram.org/file/bot#{bot.token}/#{file_path}", file_size: file_size } # lol
  end
end
