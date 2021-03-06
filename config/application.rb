require_relative 'boot'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Twilight
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    config.i18n.available_locales = [:en, :ru]
    config.assets.paths << Rails.root.join("app", "assets", "fonts")

    config.credentials = config_for(:credentials)
    config.time_zone = config.credentials[:time_zone]
    config.i18n.default_locale = config.credentials[:locale]

    require 'ext/string'

    if config.credentials[:matrix][:enabled]
      require 'ext/matrix'
    end

    def secret_key_base
      if Rails.env.test? || Rails.env.development?
        Digest::MD5.hexdigest self.class.name
      else
        validate_secret_key_base(
            ENV["SECRET_KEY_BASE"] || credentials.secret_key_base || secrets.secret_key_base
        )
      end
    end

    def credentials
      @credentials ||= encrypted("config/credentials.yml.enc")
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

  end
end