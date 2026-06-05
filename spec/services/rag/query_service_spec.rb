# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rag::QueryService do
  subject(:result) do
    described_class.call(
      conversation: conversation,
      user_message: user_message,
      user: user,
      assistant_message: assistant_message
    )
  end

  let(:conversation) { create(:conversation) }
  let(:user) { conversation.user }
  let(:assistant_message) { create(:message, :pending, conversation: conversation) }
  let(:embedding) { Array.new(1536) { rand(-1.0..1.0) } }

  def user_message
    'What documents do I need for a payroll certificate?'
  end

  def gen_result
    Rag::GenerationService::Result.new(
      success?: true,
      content: 'You need these documents for a payroll certificate...',
      metadata: { token_usage: { prompt_tokens: 100, completion_tokens: 50 } },
      error: nil
    )
  end

  before do
    allow(Rag::EmbedService).to receive(:call).with(text: user_message).and_return(
      Rag::EmbedService::Result.new(success?: true, embedding: embedding, error: nil)
    )
    allow(Rag::RetrievalService).to receive(:call).with(query_embedding: embedding).and_return(
      Rag::RetrievalService::Result.new(success?: true, chunks: [], error: nil)
    )
    allow(Rag::GenerationService).to receive(:call).and_return(gen_result)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
  end

  describe '.call' do
    context 'when relevant chunks exist and OpenAI responds' do
      before do
        chunk = create(:document_chunk, document: create(:document, :ready))
        allow(Rag::RetrievalService).to receive(:call).with(query_embedding: embedding).and_return(
          Rag::RetrievalService::Result.new(success?: true, chunks: [chunk], error: nil)
        )
      end

      it 'returns success' do
        expect(result).to be_success
      end

      it 'updates the assistant message content' do
        result
        expect(assistant_message.reload.content).to eq(
          'You need these documents for a payroll certificate...'
        )
      end

      it 'sets assistant message status to completed' do
        result
        expect(assistant_message.reload.status).to eq('completed')
      end

      it 'stores source titles in message metadata' do
        result
        expect(assistant_message.reload.metadata).to include('sources')
      end

      it 'stores token usage in message metadata' do
        result
        expect(assistant_message.reload.metadata).to include('token_usage')
      end
    end

    context 'when no relevant chunks are found' do
      before do
        allow(Rag::GenerationService).to receive(:call).with(
          hash_including(chunks: [])
        ).and_return(gen_result)
      end

      it 'calls GenerationService with empty chunks' do
        result
        expect(Rag::GenerationService).to have_received(:call).with(
          hash_including(chunks: [])
        )
      end

      it 'returns success' do
        expect(result).to be_success
      end
    end

    context 'when the embeddings API call fails' do
      before do
        allow(Rag::EmbedService).to receive(:call).with(text: user_message).and_return(
          Rag::EmbedService::Result.new(success?: false, embedding: nil, error: 'rate limited')
        )
      end

      it 'returns failure' do
        expect(result).not_to be_success
      end

      it 'sets assistant message status to failed' do
        result
        expect(assistant_message.reload.status).to eq('failed')
      end

      # rubocop:disable RSpec/MessageSpies
      it 'does not call RetrievalService' do
        expect(Rag::RetrievalService).not_to receive(:call)
        result
      end

      it 'does not call GenerationService' do
        expect(Rag::GenerationService).not_to receive(:call)
        result
      end
      # rubocop:enable RSpec/MessageSpies
    end

    context 'when the retrieval API call fails' do
      before do
        allow(Rag::RetrievalService).to receive(:call).with(query_embedding: embedding).and_return(
          Rag::RetrievalService::Result.new(success?: false, chunks: [], error: 'pgvector error')
        )
      end

      it 'returns failure' do
        expect(result).not_to be_success
      end

      it 'sets assistant message status to failed' do
        result
        expect(assistant_message.reload.status).to eq('failed')
      end

      # rubocop:disable RSpec/MessageSpies
      it 'does not call GenerationService' do
        expect(Rag::GenerationService).not_to receive(:call)
        result
      end
      # rubocop:enable RSpec/MessageSpies
    end

    context 'when the chat completion API call fails' do
      before do
        allow(Rag::GenerationService).to receive(:call).and_return(
          Rag::GenerationService::Result.new(
            success?: false, content: nil, metadata: {}, error: 'timeout'
          )
        )
      end

      it 'returns failure' do
        expect(result).not_to be_success
      end

      it 'sets assistant message status to failed' do
        result
        expect(assistant_message.reload.status).to eq('failed')
      end
    end

    context 'when the conversation has prior messages' do
      before do
        create_list(:message, 4, conversation: conversation, status: :completed)
        allow(Rag::GenerationService).to receive(:call).with(
          hash_including(conversation: conversation)
        ).and_return(gen_result)
      end

      it 'passes conversation to GenerationService' do
        result
        expect(Rag::GenerationService).to have_received(:call).with(
          hash_including(conversation: conversation)
        )
      end

      it 'returns success' do
        expect(result).to be_success
      end
    end

    context 'when the user has an active certificate request' do
      before do
        create(:certificate_request, user: user, status: :submitted)
        allow(Rag::GenerationService).to receive(:call).with(
          hash_including(user: user)
        ).and_return(gen_result)
      end

      it 'passes the user to GenerationService' do
        result
        expect(Rag::GenerationService).to have_received(:call).with(
          hash_including(user: user)
        )
      end
    end

    it 'starts with pending status' do
      expect(assistant_message.status).to eq('pending')
    end

    it 'transitions assistant message to completed after call' do
      result
      expect(assistant_message.reload.status).to eq('completed')
    end

    it 'sets the conversation title from the user message' do
      conversation.update!(title: nil)
      result
      expect(conversation.reload.title).to eq(user_message.truncate(60))
    end
  end
end
