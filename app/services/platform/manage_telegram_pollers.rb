# frozen_string_literal: true

class Platform::ManageTelegramPollers
  prepend SimpleCommand

  attr_accessor :bot, :action

  def initialize(bot, action)
    @bot = bot
    @action = action
  end

  def call
    return if bot.nil?

    action == 'add' ? add_tg_poller : delete_tg_poller
  end

  def add_tg_poller
    thread =
      Thread.new do
        execution_context = Rails.application.executor.run!
        Telegram::Bot::UpdatesPoller.add(bot, TelegramController).start
      ensure
        execution_context&.complete!
      end
    Twilight::Application::CURRENT_TG_BOTS.merge!({ bot.token.to_s => { thread: thread, client: bot } })
  end

  def delete_tg_poller
    # see other channels, no channels => delete
    token = bot.token
    return unless Channel.where(token: token, enabled: true).count == 1

    Twilight::Application::CURRENT_TG_BOTS.dig(token.to_s, :thread).kill
    Twilight::Application::CURRENT_TG_BOTS.delete(token)
  end
end
