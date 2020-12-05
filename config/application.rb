require_relative 'boot'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Twilight
  class Application < Rails::Application
    config.i18n.default_locale = :en
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    config.time_zone = 'UTC'

    config.i18n.available_locales = [:en]
    config.assets.paths << Rails.root.join("app", "assets", "fonts")

    config.credentials = config_for(:credentials)

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