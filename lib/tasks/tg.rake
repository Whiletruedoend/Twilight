# frozen_string_literal: true

namespace :tg do
  desc 'Run tg poller (for debug)'
  task start: :environment do
    puts('TELEGRAM POLLER STARTED! (RAKE)'.green) if Rails.env.development?
    threads = []
    Telegram.bots.each_value do |bot|
      threads << Thread.new do
        Telegram::Bot::UpdatesPoller.add(bot, TelegramController).start
      end
    end
    threads.each(&:join)
  end
end
