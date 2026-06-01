# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Documents::IngestJob, type: :job do
  let(:document) { create(:document, :pending) }

  # Stub all three services to prevent real calls.
  # The service classes don't exist yet (Phase 4 is pending); we define
  # minimal stub classes here so the job can reference them.
  before do
    stub_const('Documents::TextExtractorService', Class.new do
      def self.call(...); end
    end)
    stub_const('Documents::ChunkingService', Class.new do
      def self.call(...); end
    end)
    stub_const('Documents::EmbedService', Class.new do
      def self.call(...); end
    end)

    allow(Documents::TextExtractorService).to receive(:call).and_return(
      instance_double(
        'Documents::TextExtractorService::Result',
        success?: true, text: 'Extracted text content', error: nil
      )
    )
    allow(Documents::ChunkingService).to receive(:call).and_return(
      [{ document_id: document.id, content: 'chunk text', chunk_index: 0,
         metadata: '{}', created_at: Time.current, updated_at: Time.current }]
    )
    allow(Documents::EmbedService).to receive(:call).and_return(
      instance_double(
        'Documents::EmbedService::Result',
        success?: true,
        chunks: [{ document_id: document.id, content: 'chunk text', chunk_index: 0,
                   metadata: '{}', embedding: Array.new(1536, 0.0),
                   created_at: Time.current, updated_at: Time.current }],
        error: nil
      )
    )
    allow(DocumentChunk).to receive(:insert_all)
  end

  describe '#perform' do
    context 'happy path' do
      it 'transitions document from pending to ready' do
        described_class.perform_now(document.id)
        expect(document.reload.status).to eq('ready')
      end

      it 'sets chunks_count on the document' do
        described_class.perform_now(document.id)
        expect(document.reload.chunks_count).to eq(1)
      end

      it 'calls insert_all to persist chunks' do
        expect(DocumentChunk).to receive(:insert_all)
        described_class.perform_now(document.id)
      end
    end

    context 'idempotency' do
      it 'skips processing if document is already ready' do
        document.update!(status: :ready)
        expect(Documents::TextExtractorService).not_to receive(:call)
        described_class.perform_now(document.id)
      end

      it 'skips processing if document is already failed' do
        document.update!(status: :failed)
        expect(Documents::TextExtractorService).not_to receive(:call)
        described_class.perform_now(document.id)
      end
    end

    context 'when text extraction fails' do
      before do
        allow(Documents::TextExtractorService).to receive(:call).and_return(
          instance_double(
            'Documents::TextExtractorService::Result',
            success?: false, text: nil, error: 'PDF parsing error'
          )
        )
      end

      it 'sets document status to failed' do
        described_class.perform_now(document.id)
        expect(document.reload.status).to eq('failed')
      end

      it 'stores the error message on the document' do
        described_class.perform_now(document.id)
        expect(document.reload.processing_error).to include('PDF parsing error')
      end

      it 'does not call ChunkingService' do
        expect(Documents::ChunkingService).not_to receive(:call)
        described_class.perform_now(document.id)
      end
    end

    context 'when embedding fails' do
      before do
        allow(Documents::EmbedService).to receive(:call).and_return(
          instance_double(
            'Documents::EmbedService::Result',
            success?: false, chunks: nil, error: 'OpenAI rate limited'
          )
        )
      end

      it 'sets document status to failed' do
        described_class.perform_now(document.id)
        expect(document.reload.status).to eq('failed')
      end

      it 'does not persist any chunks' do
        expect(DocumentChunk).not_to receive(:insert_all)
        described_class.perform_now(document.id)
      end
    end

    context 'when the document has been deleted' do
      it 'does not raise' do
        document.destroy
        expect { described_class.perform_now(document.id) }.not_to raise_error
      end
    end

    context 'queue configuration' do
      it 'is enqueued on the ingestion queue' do
        expect(described_class.queue_name).to eq('ingestion')
      end
    end
  end
end
