# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rag::EmbedService do
  describe '.call' do
    subject(:result) { described_class.call(text: text) }

    let(:text) { 'This is a sample document text to embed.' }

    context 'with valid text' do
      before { stub_openai_embedding(text: text) }

      it 'returns success' do
        expect(result).to be_success
      end

      it 'returns an embedding array with 1536 dimensions' do
        expect(result.embedding).to be_an(Array)
        expect(result.embedding.length).to eq(1536)
      end

      it 'each embedding value is a float' do
        expect(result.embedding).to all(be_a(Float))
      end

      it 'makes a request to the OpenAI embeddings API' do
        result
        expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/embeddings')
          .with(body: hash_including(model: 'text-embedding-3-small'))
      end
    end

    context 'with very long text exceeding 8000 characters' do
      let(:text) { 'A' * 10_000 }

      before { stub_openai_embedding(text: text.truncate(8000)) }

      it 'returns success with a valid embedding' do
        expect(result).to be_success
        expect(result.embedding.length).to eq(1536)
      end

      it 'truncates the input to 8000 characters' do
        result
        # The stubbed request is matched by body, so if the stub matches,
        # the truncation worked correctly
        expect(WebMock).to have_requested(:post, 'https://api.openai.com/v1/embeddings')
      end
    end

    context 'when the OpenAI API returns an error' do
      before do
        stub_request(:post, 'https://api.openai.com/v1/embeddings')
          .to_return(status: 429, body: { error: { message: 'Rate limit exceeded' } }.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns failure' do
        expect(result).not_to be_success
      end

      it 'includes the error message' do
        expect(result.error).to be_present
      end

      it 'does not raise an exception' do
        expect { result }.not_to raise_error
      end
    end
  end
end
