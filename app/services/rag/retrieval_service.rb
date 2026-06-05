# frozen_string_literal: true

module Rag
  class RetrievalService
    # Number of nearest neighbors to return to the caller after threshold filtering.
    TOP_K = 5
    # Number of candidates to fetch from the database before applying the threshold
    # filter in Ruby.  This is higher than TOP_K so that the LIMIT in SQL doesn't
    # chop off chunks that would pass the similarity check.
    CANDIDATE_POOL = 30
    # Minimum cosine similarity (0 = orthogonal, 1 = identical).  Chunks below
    # this value are discarded.
    SIMILARITY_THRESHOLD = 0.65

    Result = Struct.new(:success?, :chunks, :error, keyword_init: true)

    def self.call(query_embedding:)
      new(query_embedding: query_embedding).call
    end

    def initialize(query_embedding:)
      @query_embedding = query_embedding
    end

    def call
      # 1. Fetch a generous pool of nearest neighbors via SQL (order + limit).
      # 2. Filter by similarity threshold in Ruby.
      # 3. Return only the TOP_K best matches.
      candidates = DocumentChunk
                   .for_ready_documents
                   .nearest_neighbors(:embedding, @query_embedding, distance: 'cosine')
                   .first(CANDIDATE_POOL)
      chunks = candidates
               .select { |c| c.neighbor_distance <= (1 - SIMILARITY_THRESHOLD) }
               .first(TOP_K)

      Result.new(success?: true, chunks: chunks, error: nil)
    rescue StandardError => e
      Result.new(success?: false, chunks: [], error: e.message)
    end
  end
end
