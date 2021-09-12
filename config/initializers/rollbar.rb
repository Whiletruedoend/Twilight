# frozen_string_literal: true

Rollbar.configure do |config|
  config.access_token = Rails.configuration.credentials[:rollbar][:token]
  config.enabled = Rails.configuration.credentials[:rollbar][:enabled]
  config.environment = ENV['ROLLBAR_ENV'].presence || Rails.env
end
