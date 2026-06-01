# frozen_string_literal: true

Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: Rails.application.credentials.dig(:redis, :url) || ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
)

Rack::Attack.throttle('messages/user', limit: 20, period: 60) do |req|
  req.env['warden']&.user&.id if req.path == '/messages' && req.post?
end

Rack::Attack.throttled_responder = lambda do |_req|
  [429, { 'Content-Type' => 'application/json' },
   [{ error: 'Rate limit exceeded. Please wait before sending another message.' }.to_json]]
end
