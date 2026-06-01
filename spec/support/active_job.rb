# frozen_string_literal: true

# ActiveJob test helper configuration.
# Sets the test adapter so jobs are enqueued but not executed during specs.

RSpec.configure do |config|
  config.include ActiveJob::TestHelper

  config.before(:each) do
    ActiveJob::Base.queue_adapter = :test
  end
end
