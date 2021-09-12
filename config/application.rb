# frozen_string_literal: true

require_relative 'boot'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Twilight
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    config.i18n.available_locales = %i[en ru]
    config.assets.paths << Rails.root.join('app', 'assets', 'fonts')

    config.credentials = config_for(:credentials)
    config.time_zone = config.credentials[:time_zone]
    config.i18n.default_locale = config.credentials[:locale]

    require 'ext/string'
    require 'ext/matrix'
    require 'ext/zip_file_generator'
    require 'redcarpet/custom_render'

    def secret_key_base
      if Rails.env.test? || Rails.env.development?
        Digest::MD5.hexdigest self.class.name
      else
        validate_secret_key_base(
          ENV['SECRET_KEY_BASE'] || credentials.secret_key_base || secrets.secret_key_base
        )
      end
    end

    def credentials
      @credentials ||= encrypted('config/credentials.yml.enc')
    end

    config.after_initialize do
      THEMES = Dir.glob("#{Rails.root}/app/assets/stylesheets/*_theme.scss").map { |s| File.basename(s, '.*') }
      if ActiveRecord::Base.connection.data_source_exists?('platforms') && ActiveRecord::Base.connection.data_source_exists?('channels')
        Platform.find_or_initialize_by(title: 'telegram').save
        Platform.find_or_initialize_by(title: 'matrix').save

        tokens = Channel.all.where(platform: Platform.find_by(title: 'telegram')).map do |channel|
          [channel.options['id'].to_s, channel.token]
        end.to_h

        if tokens.empty?
          Telegram.bots_config = { default: '123456' } # avoid tg error
        else
          default_token =
            tokens.each_with_object({}) do |(k, v), option|
              option[:default] = v if k == tokens.keys.first
            end
          tokens.delete(tokens.keys.first)
          tokens.merge!(default_token)

          Telegram.bots_config = tokens

          # RunTelegramPoller.perform_later
        end
      else
        Telegram.bots_config = { default: '123456' } # avoid tg error
      end
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
