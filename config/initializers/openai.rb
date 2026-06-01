# frozen_string_literal: true

require 'openai'

OpenAI.configure do |config|
  config.access_token = Rails.application.credentials.dig(:openai, :api_key)
  config.log_errors = Rails.env.development?
end
