# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rag::GenerationService do
  subject(:result) do
    described_class.call(
      conversation: conversation,
      chunks: chunks,
      user_message: user_message,
      user: user,
      assistant_message: assistant_message
    )
  end

  let(:conversation) { create(:conversation) }
  let(:user) { conversation.user }
  let(:user_message) { 'What documents do I need for a payroll certificate?' }
  let(:assistant_message) { create(:message, :pending, conversation: conversation) }

  let(:chunks) do
    [
      double('DocumentChunk',
             content: 'Payroll certificates require: proof of employment and ID.',
             source_title: 'HR Policy Manual',
             neighbor_distance: 0.15),
      double('DocumentChunk',
             content: 'Processing time for payroll certificates is 3-5 business days.',
             source_title: 'Certificate FAQ',
             neighbor_distance: 0.22)
    ]
  end

  let(:fake_response) do
    {
      'choices' => [
        { 'message' => { 'role' => 'assistant',
                         'content' => 'You need these documents for a payroll certificate...' },
          'finish_reason' => 'stop' }
      ],
      'usage' => { 'prompt_tokens' => 100, 'completion_tokens' => 50, 'total_tokens' => 150 }
    }
  end

  before do
    client = instance_double(OpenAI::Client)
    allow(OpenAI::Client).to receive(:new).and_return(client)
    allow(client).to receive(:chat).and_return(fake_response)
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
  end

  describe '.call' do
    # INVARIANT 1: System prompt is ALWAYS the first message
    it 'sends the system prompt as the first message to OpenAI' do
      client = instance_double(OpenAI::Client)
      allow(OpenAI::Client).to receive(:new).and_return(client)

      expect(client).to receive(:chat) do |params|
        first = params[:parameters][:messages].first
        expect(first[:role]).to eq('system')
        expect(first[:content]).to include('Pipelin')
        fake_response
      end

      result
    end

    # INVARIANT 2: Chunk content is ALWAYS included in the prompt
    it 'includes retrieved chunk content in the prompt' do
      client = instance_double(OpenAI::Client)
      allow(OpenAI::Client).to receive(:new).and_return(client)

      expect(client).to receive(:chat) do |params|
        combined = params[:parameters][:messages].map { |m| m[:content] }.join(' ')
        chunks.each do |chunk|
          expect(combined).to include(chunk.content[0..30])
        end
        fake_response
      end

      result
    end

    # INVARIANT 3: User question is ALWAYS the last message
    it 'sends the user message as the last message to OpenAI' do
      client = instance_double(OpenAI::Client)
      allow(OpenAI::Client).to receive(:new).and_return(client)

      expect(client).to receive(:chat) do |params|
        msgs = params[:parameters][:messages]
        expect(msgs.last[:role]).to eq('user')
        expect(msgs.last[:content]).to eq(user_message)
        fake_response
      end

      result
    end

    # Happy path
    it 'returns success' do
      expect(result).to be_success
    end

    it 'returns the full response content' do
      expect(result.content).to eq('You need these documents for a payroll certificate...')
    end

    it 'includes token usage in metadata' do
      expect(result.metadata[:token_usage]).to include(:prompt_tokens, :completion_tokens)
    end

    # No hallucination guard: when no chunks, no context block is injected
    context 'when no chunks are provided' do
      let(:chunks) { [] }

      it 'returns success' do
        expect(result).to be_success
      end

      it 'does not inject a context documents block' do
        client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(client)

        expect(client).to receive(:chat) do |params|
          combined = params[:parameters][:messages].map { |m| m[:content] }.join(' ')
          expect(combined).not_to include('Relevant context from company documents')
          fake_response
        end

        result
      end
    end

    # Conversation history included
    context 'when the conversation has prior messages' do
      before do
        create_list(:message, 3, conversation: conversation, status: :completed)
      end

      it 'includes prior messages in the prompt' do
        client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(client)

        expect(client).to receive(:chat) do |params|
          roles = params[:parameters][:messages].map { |m| m[:role] }
          expect(roles).to include('user', 'assistant')
          fake_response
        end

        result
      end
    end

    # Certificate context included when user has active requests
    context 'when the user has active certificate requests' do
      let!(:cert_request) { create(:certificate_request, user: user, status: :submitted) }

      it 'includes certificate request data in the prompt' do
        client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(client)

        expect(client).to receive(:chat) do |params|
          combined = params[:parameters][:messages].map { |m| m[:content] }.join(' ')
          expect(combined).to include(cert_request.reference_number)
          fake_response
        end

        result
      end
    end

    # Failure handling
    context 'when the OpenAI API fails' do
      before do
        client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(client)
        allow(client).to receive(:chat).and_raise(OpenAI::Error, 'API timeout')
      end

      it 'returns failure' do
        expect(result).not_to be_success
      end

      it 'includes an error message' do
        expect(result.error).to be_present
      end
    end
  end
end
