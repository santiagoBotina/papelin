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
  let(:assistant_message) { create(:message, :pending, conversation: conversation) }
  let(:user) { conversation.user }
  let(:chunks) { build_chunks }

  def build_chunks
    chunk_class = Struct.new(:content, :source_title, :neighbor_distance, keyword_init: true)
    [
      chunk_class.new(content: 'Payroll certificates require: proof of employment and ID.',
                      source_title: 'HR Policy Manual', neighbor_distance: 0.15),
      chunk_class.new(content: 'Processing time for payroll certificates is 3-5 business days.',
                      source_title: 'Certificate FAQ', neighbor_distance: 0.22)
    ]
  end

  def user_message
    'What documents do I need for a payroll certificate?'
  end

  def fake_response
    {
      'choices' => [
        { 'message' => { 'role' => 'assistant',
                         'content' => 'You need these documents for a payroll certificate...' },
          'finish_reason' => 'stop' }
      ],
      'usage' => { 'prompt_tokens' => 100, 'completion_tokens' => 50, 'total_tokens' => 150 }
    }
  end

  describe '.call' do
    let(:captured_params) { {} }

    before do
      client = instance_double(OpenAI::Client)
      allow(OpenAI::Client).to receive(:new).and_return(client)
      allow(client).to receive(:chat) do |params|
        captured_params[:data] = params
        fake_response
      end
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
    end

    it 'returns success' do
      expect(result).to be_success
    end

    it 'returns the full response content' do
      expect(result.content).to eq('You need these documents for a payroll certificate...')
    end

    it 'includes token usage in metadata' do
      expect(result.metadata[:token_usage]).to include(:prompt_tokens, :completion_tokens)
    end

    it 'sends the system prompt as the first message' do
      result
      msg = captured_params.dig(:data, :parameters, :messages).first
      expect(msg[:role]).to eq('system')
    end

    it 'includes the company name in the system prompt' do
      result
      msg = captured_params.dig(:data, :parameters, :messages).first
      expect(msg[:content]).to include('Papelin')
    end

    it 'includes retrieved chunk content in the prompt' do
      result
      combined = captured_params.dig(:data, :parameters, :messages).pluck(:content).join(' ')
      expect(combined).to include(chunks.first.content[0..30])
    end

    it 'sends the user message as the last message' do
      result
      msgs = captured_params.dig(:data, :parameters, :messages)
      expect(msgs.last[:role]).to eq('user')
    end

    it 'sends the user message content as the last message content' do
      result
      msgs = captured_params.dig(:data, :parameters, :messages)
      expect(msgs.last[:content]).to eq(user_message)
    end

    context 'when no chunks are provided' do
      let(:chunks) { [] }

      it 'returns success' do
        expect(result).to be_success
      end

      it 'does not inject a context documents block' do
        result
        combined = captured_params.dig(:data, :parameters, :messages).pluck(:content).join(' ')
        expect(combined).not_to include('Relevant context from company documents')
      end
    end

    context 'when the conversation has prior messages' do
      before do
        create_list(:message, 3, conversation: conversation, status: :completed)
      end

      it 'includes prior messages in the prompt' do
        result
        roles = captured_params.dig(:data, :parameters, :messages).pluck(:role)
        expect(roles).to include('user', 'assistant')
      end
    end

    context 'when the user has active certificate requests' do
      it 'includes certificate request data in the prompt' do
        cert = create(:certificate_request, user: user, status: :submitted)
        result
        combined = captured_params.dig(:data, :parameters, :messages).pluck(:content).join(' ')
        expect(combined).to include(cert.reference_number)
      end
    end

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
