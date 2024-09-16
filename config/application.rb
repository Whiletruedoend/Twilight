require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Twilight
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    config.i18n.available_locales = %i[en ru]
    config.assets.paths << Rails.root.join('app', 'assets', 'fonts')

    config.credentials = config_for(:credentials)
    config.time_zone = config.credentials[:time_zone]
    config.i18n.default_locale = config.credentials[:locale]

    config.active_storage.variant_processor = :mini_magick

    config.active_record.yaml_column_permitted_classes = [Time] # PaperTrail fix

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
      CURRENT_TG_BOTS = {}
    end
    # config.eager_load_paths << Rails.root.join("extras")

    ## Hosts access ##
    config.hosts = [
      IPAddr.new("0.0.0.0/0"),
      IPAddr.new("::/0"),
      "localhost",
      "twilight",
      ENV['HOST_URL']
    ]

    config.action_cable.allowed_request_origins = ["http://#{ENV['HOST_URL']}", "https://#{ENV['HOST_URL']}"]

    if ENV['DOCKERIZED'] == 'true'
      config.web_console.whitelisted_ips = ENV['DOCKER_HOST_IP']
    end
  end
end
