# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Documents::EmbedService do
  describe '.call' do
    subject(:result) { described_class.call(chunks: chunks) }

    context 'with valid chunks' do
      let(:chunks) { build_chunk_hashes(count: 3) }

      before { stub_openai_embedding }

      it 'returns success' do
        expect(result).to be_success
      end

      it 'adds an :embedding key to every chunk' do
        expect(result.chunks).to all(have_key(:embedding))
      end

      it 'each embedding has 1536 dimensions' do
        embeddings = result.chunks.pluck(:embedding)
        expect(embeddings).to all(be_an(Array).and(have_attributes(length: 1536)))
      end

      it 'does not modify the original chunk hash keys' do
        original_keys = chunks.first.keys
        expect(result.chunks).to all(include(*original_keys))
      end

      it 'calls Rag::EmbedService for each chunk' do
        expect(Rag::EmbedService).to receive(:call).exactly(3).times.and_call_original
        result
      end
    end

    context 'with an empty chunks array' do
      let(:chunks) { [] }

      it 'returns success with empty chunks' do
        expect(result).to be_success
        expect(result.chunks).to eq([])
      end

      it 'makes no OpenAI API calls' do
        expect(Rag::EmbedService).not_to receive(:call)
        result
      end
    end

    context 'when Rag::EmbedService fails for one chunk' do
      let(:chunks) { build_chunk_hashes(count: 3) }

      before do
        allow(Rag::EmbedService).to receive(:call)
          .and_return(
            Rag::EmbedService::Result.new(success?: true,
                                          embedding: Array.new(1536, 0.0),
                                          error: nil),
            Rag::EmbedService::Result.new(success?: false,
                                          embedding: nil,
                                          error: 'rate limited')
          )
      end

      it 'returns failure' do
        expect(result).not_to be_success
      end

      it 'includes the failing chunk index in the error message' do
        expect(result.error).to include('1')
      end

      it 'does not return partial results' do
        expect(result.chunks).to be_nil
      end
    end
  end
end
