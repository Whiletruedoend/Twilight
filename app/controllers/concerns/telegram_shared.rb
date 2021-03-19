module TelegramShared
  extend ActiveSupport::Concern

  def get_chat_avatar(bot, chat_id)
    begin
      photo_msg = bot.get_chat(chat_id: chat_id)
    rescue
      photo_msg = nil
    end
    if photo_msg.present? && photo_msg["result"]["photo"].present?
      photo = photo_msg["result"]["photo"]
      file_id = photo["big_file_id"]
      file_path = bot.get_file(file_id: file_id)["result"]["file_path"]
      { link: "https://api.telegram.org/file/bot#{bot.token}/#{file_path}", file_size: "1" } # lol
    else
      nil
    end
  end

end
