# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.3.0'

gem 'pg', '~> 1.5'
gem 'puma', '~> 6.0'
gem 'rails', '~> 7.2.0'

# Hotwire
gem 'stimulus-rails'
gem 'turbo-rails'

# Frontend
gem 'importmap-rails'
gem 'sprockets-rails'
gem 'tailwindcss-rails'

# Auth
gem 'devise'
gem 'pundit'

# AI / Vector
gem 'neighbor'
gem 'ruby-openai', '~> 7.0'

# File uploads
gem 'active_storage_validations'

# Background jobs
gem 'redis'
gem 'sidekiq', '~> 7.0'
gem 'sidekiq-cron'

# Document parsing
gem 'docx'
gem 'pdf-reader'

# Performance & security
gem 'pagy', '~> 6.5'
gem 'rack-attack'

# Markdown rendering (assistant output)
gem 'redcarpet'

# Compatibility pin for Ruby 3.3 (connection_pool 3.x uses newer syntax)
gem 'connection_pool', '~> 2.5'

# Utilities
gem 'bootsnap', require: false

group :development, :test do
  gem 'dotenv-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rspec-rails'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
  gem 'vcr'
  gem 'webmock'
end

group :development do
  gem 'bullet'
  gem 'letter_opener'
  gem 'rack-mini-profiler'
  gem 'web-console'
end
