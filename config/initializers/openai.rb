# frozen_string_literal: true

require 'openai'

OpenAI.configure do |config|
  config.access_token = ENV['OPENAI_API_KEY'].presence ||
                        Rails.application.credentials.dig(:openai, :api_key)
  config.log_errors = Rails.env.development?
end
