# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'

run Rails.application

begin
  if ActiveRecord::Base.connection.data_source_exists?('platforms') &&
     ActiveRecord::Base.connection.data_source_exists?('channels')

    Platform.find_or_initialize_by(title: 'telegram').save
    Platform.find_or_initialize_by(title: 'matrix').save

    if Rails.configuration.credentials&.dig(:redis, :autostart)
      Thread.new do
        execution_context = Rails.application.executor.run!
        `redis-server`
      ensure
        execution_context&.complete!
      end
    end

    redis_url = Rails.configuration.credentials&.dig(:redis, :url)
    REDIS = Redis.new(url: redis_url) if redis_url.present?
    RunTelegramPoller.perform_now
  end
rescue StandardError => e
  puts(e)
end
