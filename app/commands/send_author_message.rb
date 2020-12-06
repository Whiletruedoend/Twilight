class SendAuthorMessage
  prepend SimpleCommand

  attr_accessor :login

  def initialize(login)
    @login = login
  end

  def call
    Telegram.bot.send_message(chat_id: Rails.configuration.credentials['telegram']['author'], text: "Registration | #{DateTime.now.strftime("%d.%m.%Y %H:%M")} | Login: #{login}")
  end

end