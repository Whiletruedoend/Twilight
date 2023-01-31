# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'

run Rails.application

if ActiveRecord::Base.connection.data_source_exists?('platforms') && ActiveRecord::Base.connection.data_source_exists?('channels')
  Platform.find_or_initialize_by(title: 'telegram').save
  Platform.find_or_initialize_by(title: 'matrix').save

  if Rails.configuration.credentials[:redis][:autostart]
    Thread.new do
      execution_context = Rails.application.executor.run!
      %x[redis-server]
    ensure
      execution_context&.complete!
    end
  end

  REDIS = Redis.new(url: Rails.configuration.credentials[:redis][:url] )
  RunTelegramPoller.perform_now
end
