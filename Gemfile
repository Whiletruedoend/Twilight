# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.7.7'

gem 'activerecord', '>= 6.1.7.1'
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 7.0.4.2'
# Use sqlite3 as the database for Active Record
gem 'sqlite3', '>= 1.4'
# Use Puma as the app server
gem 'puma', '>= 5.6.4'
# Use SCSS for stylesheets
gem 'sass-rails', '>= 6'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacke
gem 'webpacker', '>= 5.4.2'
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '>= 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '>= 2.7'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'
gem 'actionpack', '>= 6.1.4.1'
# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.b
gem 'bootsnap', '>= 1.4.4', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rspec'
  gem 'rspec-rails'
  gem 'rubocop-rspec', require: false
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code
  gem 'web-console', '>= 4.1.0'
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem 'listen', '~> 3.3'
  gem 'rack-mini-profiler', '~> 2.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 3.26'
  gem 'selenium-webdriver'
  # Easy installation and use of web drivers to run system tests with browsers
  gem 'webdrivers'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

gem 'net-http'
gem 'colorize'

# rubocop
gem 'code-scanning-rubocop'
gem 'panolint'
gem 'rubocop'
gem 'rubocop-rails'

gem 'action_policy'
gem 'active_storage_validations'
gem 'addressable', '>= 2.8.0'
gem 'betterlorem'
gem 'devise'
gem 'dry-initializer-rails'
gem 'easy_captcha', github: 'kopylovvlad/easy_captcha'
gem 'enumerize'
gem 'grape'
gem 'image_processing', '>= 1.12.2'
gem 'mini_magick'
gem 'nokogiri', '>= 1.11.0.rc4'
gem 'open-uri'
gem 'pg'
gem 'redcarpet'
gem 'reverse_markdown'
gem 'rmagick', '~> 4.1.1'
gem 'rollbar'
gem 'rubyzip'
gem 'simple_command'
gem 'socksify', require: false # TCP through a SOCKS5 proxy
gem 'telegram-bot'

gem 'sidekiq'

gem 'bootstrap-sass'
gem 'bootstrap-will_paginate', '~> 0.0.10'
gem 'font-awesome-rails'
gem 'font-awesome-sass', '~> 5.15.1'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'rails_sortable'
gem 'therubyracer', platforms: :ruby
gem 'will_paginate', '~> 3.3.1'

gem 'dotenv-rails'