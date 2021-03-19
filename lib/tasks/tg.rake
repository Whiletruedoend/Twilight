namespace :tg do
  desc 'Run tg poller (for debug)'
  task :start => :environment do
    puts("TELEGRAM POLLER STARTED! (RAKE)".green) if Rails.env.development?
    threads = []
    Telegram.bots.values.each { |bot| threads << Thread.new { Telegram::Bot::UpdatesPoller.add(bot, TelegramController).start } }
    threads.each { |th| th.join }
  end
end