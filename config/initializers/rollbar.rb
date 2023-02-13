# frozen_string_literal: true

Rollbar.configure do |config|
  config.access_token = Rails.configuration.credentials&.dig(:rollbar, :auth_token)
  config.enabled = Rails.configuration.credentials&.dig(:rollbar, :enabled) || false
  config.environment = ENV['ROLLBAR_ENV'].presence || Rails.env
end
