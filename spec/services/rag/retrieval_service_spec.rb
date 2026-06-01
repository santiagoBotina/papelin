# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rag::RetrievalService do
  let(:embedding) { Array.new(1536) { rand(-1.0..1.0) } }

  describe '.call' do
    subject(:result) { described_class.call(query_embedding: embedding) }

    context 'when matching chunks exist in ready documents' do
      let(:chunk) do
        double('DocumentChunk',
               id: 1,
               content: 'Relevant policy about certificates',
               chunk_index: 0,
               source_title: 'HR Policy Manual',
               neighbor_distance: 0.1)
      end
      let(:chunks_result) { [chunk] }

      before do
        allow(DocumentChunk).to receive(:for_ready_documents).and_return(DocumentChunk)
        allow(DocumentChunk).to receive(:nearest_neighbors)
          .with(:embedding, embedding, distance: 'cosine')
          .and_return(chunks_result)
      end

      it 'returns success' do
        expect(result).to be_success
      end

      it 'returns the matching chunks' do
        expect(result.chunks).to contain_exactly(chunk)
      end
    end

    context 'when chunks exist but are below the similarity threshold' do
      let(:distant_chunk) do
        double('DocumentChunk', neighbor_distance: 0.9, content: 'Irrelevant content')
      end
      let(:chunks_result) { [distant_chunk] }

      before do
        allow(DocumentChunk).to receive(:for_ready_documents).and_return(DocumentChunk)
        allow(DocumentChunk).to receive(:nearest_neighbors)
          .with(:embedding, embedding, distance: 'cosine')
          .and_return(chunks_result)
      end

      it 'returns success' do
        expect(result).to be_success
      end

      it 'returns empty chunks array' do
        expect(result.chunks).to be_empty
      end
    end

    context 'when the document is not ready' do
      before do
        document = create(:document, :processing)
        create(:document_chunk, document: document)
        allow(DocumentChunk).to receive(:for_ready_documents).and_return(DocumentChunk.none)
        allow(DocumentChunk).to receive(:nearest_neighbors).and_raise('should not be called')
      end

      it 'does not include chunks from non-ready documents' do
        expect(result.chunks).to be_empty
      end
    end

    context 'when pgvector raises an error' do
      before do
        allow(DocumentChunk).to receive(:for_ready_documents).and_raise(PG::Error, 'vector index error')
      end

      it 'returns failure' do
        expect(result).not_to be_success
      end

      it 'includes the error message' do
        expect(result.error).to be_present
      end

      it 'does not raise' do
        expect { result }.not_to raise_error
      end
    end
  end
end
