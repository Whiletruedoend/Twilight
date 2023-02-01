# frozen_string_literal: true

class RunTelegramPoller < ApplicationJob
  queue_as :default

  def perform(*)
    Rails.logger.debug('TELEGRAM POLLER STARTED!'.green) if Rails.env.development?
    Telegram.bots.each_value.each do |bot|
      thread =
        Thread.new do
          execution_context = Rails.application.executor.run!
          Telegram::Bot::UpdatesPoller.add(bot, TelegramController).start
        rescue Telegram::Bot::Error => e
          Twilight::Application::CURRENT_TG_BOTS.delete(bot.token)
          Channel.where(token: bot.token, enabled: true).update!(enabled: false)
          Rails.logger.debug("Thread killed due telegram error: #{e}".red) if Rails.env.development?
          thread.kill
        ensure
          execution_context&.complete!
        end
      Twilight::Application::CURRENT_TG_BOTS.merge!({ bot.token.to_s => { thread: thread, client: bot } })
    end
  end
end
