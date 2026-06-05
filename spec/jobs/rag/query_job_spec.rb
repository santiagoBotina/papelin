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
      double(success?: true, message: assistant_message, error: nil)
    )
  end

  describe '#perform' do
    context 'when on the happy path' do
      it 'calls Rag::QueryService with correct arguments' do
        described_class.perform_now(assistant_message.id, user_content)
        expect(Rag::QueryService).to have_received(:call).with(conversation: conversation,
                                                               user_message: user_content, user: user,
                                                               assistant_message: assistant_message)
      end
    end

    context 'when running idempotently' do
      it 'skips if message is already completed' do
        assistant_message.update!(status: :completed, content: 'already done')
        # rubocop:disable RSpec/MessageSpies
        expect(Rag::QueryService).not_to receive(:call)
        # rubocop:enable RSpec/MessageSpies
        described_class.perform_now(assistant_message.id, user_content)
      end

      it 'skips if message is already failed' do
        assistant_message.update!(status: :failed)
        # rubocop:disable RSpec/MessageSpies
        expect(Rag::QueryService).not_to receive(:call)
        # rubocop:enable RSpec/MessageSpies
        described_class.perform_now(assistant_message.id, user_content)
      end
    end

    context 'when Rag::QueryService returns failure' do
      before do
        allow(Rag::QueryService).to receive(:call).and_return(
          double(success?: false, message: nil, error: 'OpenAI timeout')
        )
      end

      it 'does not raise' do
        expect { described_class.perform_now(assistant_message.id, user_content) }
          .not_to raise_error
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)
        described_class.perform_now(assistant_message.id, user_content)
        expect(Rails.logger).to have_received(:error).with(/OpenAI timeout/)
      end
    end

    context 'when the message has been deleted' do
      it 'does not raise' do
        assistant_message.destroy
        expect { described_class.perform_now(assistant_message.id, user_content) }
          .not_to raise_error
      end
    end

    context 'with queue configuration' do
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
