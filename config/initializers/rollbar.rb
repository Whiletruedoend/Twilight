Rollbar.configure do |config|
  config.access_token = ""#Rails.configuration.credentials['rollbar']['token']
  config.enabled = false#Rails.configuration.credentials['rollbar']['enabled']
  config.environment = ENV['ROLLBAR_ENV'].presence || Rails.env
end