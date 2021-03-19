class RunTelegramPoller < ApplicationJob
  queue_as :default

  def perform(*)
    puts("TELEGRAM POLLER STARTED!".green) if Rails.env.development?
    threads = []

    Telegram.bots.values.each { |bot| threads << Thread.new { Telegram::Bot::UpdatesPoller.add(bot, TelegramController).start } }

    threads.each { |th| th.join }
  end
end