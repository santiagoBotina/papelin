# frozen_string_literal: true

module Documents
  # Accepts an array of chunk hashes (from ChunkingService) and enriches each
  # with an :embedding key by delegating to Rag::EmbedService.
  #
  # Returns a Result with the enriched chunk array on success, or an error
  # message on the first embedding failure (no partial results).
  class EmbedService
    Result = Struct.new(:success?, :chunks, :error, keyword_init: true)

    def self.call(chunks:)
      new(chunks: chunks).call
    end

    def initialize(chunks:)
      @chunks = chunks
    end

    def call
      return Result.new(success?: true, chunks: [], error: nil) if @chunks.empty?

      enriched = @chunks.map.with_index do |chunk, index|
        embed_result = Rag::EmbedService.call(text: chunk[:content])

        unless embed_result.success?
          raise EmbeddingFailedError, "Embedding failed for chunk #{index}: #{embed_result.error}"
        end

        chunk.merge(embedding: embed_result.embedding)
      end

      Result.new(success?: true, chunks: enriched, error: nil)
    rescue EmbeddingFailedError => e
      Result.new(success?: false, chunks: nil, error: e.message)
    end

    # Raised and caught internally to abort the embedding pipeline on first failure
    class EmbeddingFailedError < StandardError; end
  end
end
