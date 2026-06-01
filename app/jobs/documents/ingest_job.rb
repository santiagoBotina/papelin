# frozen_string_literal: true

module Documents
  class IngestJob < ApplicationJob
    queue_as :ingestion

    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    discard_on ActiveJob::DeserializationError

    def perform(document_id)
      document = Document.find(document_id)

      # Idempotency guard — skip if already processed or failed
      return if document.ready? || document.failed?

      document.update!(status: :processing)

      run_ingestion_pipeline(document)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn "Documents::IngestJob: document #{document_id} not found, skipping"
    end

    private

    def run_ingestion_pipeline(document)
      extract_result = Documents::TextExtractorService.call(document: document)
      return document.fail!(extract_result.error) unless extract_result.success?

      chunks = Documents::ChunkingService.call(text: extract_result.text, document: document)
      embed_result = embed_chunks(chunks, document)
      return unless embed_result

      persist_chunks(document, embed_result)
    end

    def embed_chunks(chunks, document)
      result = Documents::EmbedService.call(chunks: chunks)
      unless result.success?
        document.fail!(result.error)
        return nil
      end

      result
    end

    def persist_chunks(document, embed_result)
      # rubocop:disable Rails/SkipsModelValidations
      # insert_all is intentional — we bulk-insert prepared chunk records and
      # rely on DB-level constraints (foreign keys, NOT NULL) for integrity.
      DocumentChunk.insert_all(embed_result.chunks) if embed_result.chunks.any?
      # rubocop:enable Rails/SkipsModelValidations
      document.update!(status: :ready, chunks_count: embed_result.chunks.size)
    end
  end
end
