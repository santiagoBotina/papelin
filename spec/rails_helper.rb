# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'

require 'shoulda/matchers'
require 'pundit/rspec'
require 'webmock/rspec'

Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

WebMock.disable_net_connect!(allow_localhost: true)

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include OpenAIHelpers
  config.include DocumentHelpers
  config.include Devise::Test::IntegrationHelpers, type: :request

  config.fixture_paths = [
    Rails.root.join('spec', 'fixtures')
  ]

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
