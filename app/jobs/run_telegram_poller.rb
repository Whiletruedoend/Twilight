# frozen_string_literal: true

class RunTelegramPoller < ApplicationJob
  queue_as :default

  def perform(*)
    Rails.logger.debug('TELEGRAM POLLER STARTED!'.green) if Rails.env.development?
    threads = []

    Telegram.bots.each_value do |bot|
      threads << Thread.new do
        Telegram::Bot::UpdatesPoller.add(bot, TelegramController).start
      end
    end

    threads.each(&:join)
  end
end
