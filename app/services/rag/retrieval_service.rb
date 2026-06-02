# frozen_string_literal: true

module Rag
  class RetrievalService
    TOP_K = 5
    SIMILARITY_THRESHOLD = 0.65

    Result = Struct.new(:success?, :chunks, :error, keyword_init: true)

    def self.call(query_embedding:)
      new(query_embedding: query_embedding).call
    end

    def initialize(query_embedding:)
      @query_embedding = query_embedding
    end

    def call
      chunks = DocumentChunk
               .for_ready_documents
               .nearest_neighbors(:embedding, @query_embedding, distance: 'cosine')
               .first(TOP_K)
               .select { |c| c.neighbor_distance <= (1 - SIMILARITY_THRESHOLD) }

      Result.new(success?: true, chunks: chunks, error: nil)
    rescue StandardError => e
      Result.new(success?: false, chunks: [], error: e.message)
    end
  end
end
