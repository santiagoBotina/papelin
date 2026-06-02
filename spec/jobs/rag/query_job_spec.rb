# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rag::QueryJob, type: :job do
  let(:conversation)      { create(:conversation) }
  let(:user)              { conversation.user }
  let(:assistant_message) { create(:message, :pending, conversation: conversation) }
  let(:user_content)      { 'What documents do I need for a payroll certificate?' }

  # The service class doesn't exist yet (Phase 5 is pending); we define a
  # minimal stub class here so the job can reference it.
  before do
    stub_const('Rag::QueryService', Class.new do
      def self.call(...); end
    end)

    allow(Rag::QueryService).to receive(:call).and_return(
      instance_double(
        Rag::QueryService::Result,
        success?: true,
        message: assistant_message,
        error: nil
      )
    )
  end

  describe '#perform' do
    context 'happy path' do
      it 'calls Rag::QueryService with correct arguments' do
        expect(Rag::QueryService).to receive(:call).with(
          conversation: conversation,
          user_message: user_content,
          user: user,
          assistant_message: assistant_message
        )
        described_class.perform_now(assistant_message.id, user_content)
      end
    end

    context 'idempotency' do
      it 'skips if message is already completed' do
        assistant_message.update!(status: :completed, content: 'already done')
        expect(Rag::QueryService).not_to receive(:call)
        described_class.perform_now(assistant_message.id, user_content)
      end

      it 'skips if message is already failed' do
        assistant_message.update!(status: :failed)
        expect(Rag::QueryService).not_to receive(:call)
        described_class.perform_now(assistant_message.id, user_content)
      end
    end

    context 'when Rag::QueryService returns failure' do
      before do
        allow(Rag::QueryService).to receive(:call).and_return(
          instance_double(
            Rag::QueryService::Result,
            success?: false,
            message: nil,
            error: 'OpenAI timeout'
          )
        )
      end

      it 'does not raise' do
        expect { described_class.perform_now(assistant_message.id, user_content) }
          .not_to raise_error
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/OpenAI timeout/)
        described_class.perform_now(assistant_message.id, user_content)
      end
    end

    context 'when the message has been deleted' do
      it 'does not raise' do
        assistant_message.destroy
        expect { described_class.perform_now(assistant_message.id, user_content) }
          .not_to raise_error
      end
    end

    context 'queue configuration' do
      it 'is enqueued on the default queue' do
        expect(described_class.queue_name).to eq('default')
      end
    end

    # Retry configuration is declared in the job class source via
    # `retry_on Faraday::TimeoutError, ...` and `retry_on Faraday::ServerError, ...`.
    # ActiveJob does not expose a public API to read these declarations at runtime,
    # so they are verified by code review rather than by a runtime assertion.
  end
end
