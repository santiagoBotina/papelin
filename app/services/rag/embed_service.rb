# frozen_string_literal: true

module Rag
  class EmbedService
    MODEL = 'text-embedding-3-small'
    DIMENSIONS = 1536
    MAX_INPUT_LENGTH = 8000

    Result = Struct.new(:success?, :embedding, :error, keyword_init: true)

    def self.call(text:)
      new(text: text).call
    end

    def initialize(text:)
      @text = text.to_s.strip.truncate(MAX_INPUT_LENGTH)
    end

    def call
      response = openai_client.embeddings(
        parameters: { model: MODEL, input: @text }
      )
      embedding = response.dig('data', 0, 'embedding')

      Result.new(success?: true, embedding: embedding, error: nil)
    rescue Faraday::Error, OpenAI::Error => e
      Result.new(success?: false, embedding: nil, error: e.message)
    end

    private

    def openai_client
      @openai_client ||= OpenAI::Client.new
    end
  end
end
