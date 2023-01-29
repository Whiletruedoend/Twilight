# frozen_string_literal: true

namespace :tg do
  desc 'Run tg poller (for debug)'
  task start: :environment do
    puts('TELEGRAM POLLER STARTED! (RAKE)'.green) if Rails.env.development?
    Telegram.bots.each_value.each do |bot|
      Thread.new do
        execution_context = Rails.application.executor.run!
        Telegram::Bot::UpdatesPoller.add(bot, TelegramController).start
      ensure
        execution_context&.complete!
      end
    end
  end
end
