# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:conversation) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:role) }
    # R1 (phase-2 plan): see conversation_spec.rb — same fix for the
    # implicit `belongs_to` presence validation.
    it { is_expected.to belong_to(:conversation).required }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:role).with_values(user: 0, assistant: 1, system: 2) }
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, streaming: 1, completed: 2, failed: 3) }
  end

  describe 'scopes' do
    describe '.completed' do
      # Verbatim from PROMPT.md §2.3: positive AND negative inclusion in one example.
      it 'returns only completed messages' do
        completed = create(:message, status: :completed)
        pending   = create(:message, status: :pending)
        expect(described_class.completed).to include(completed)
        expect(described_class.completed).not_to include(pending)
      end
    end
  end

  describe '#append_content!' do
    let(:message) { create(:message, :assistant, content: 'Hello') }

    it 'appends a token to the content' do
      message.append_content!(' world')
      expect(message.reload.content).to eq('Hello world')
    end
  end

  describe '#sources' do
    it 'returns source documents from metadata' do
      message = build(:message, metadata: { 'sources' => [{ 'title' => 'HR Manual' }] })
      expect(message.sources).to eq([{ 'title' => 'HR Manual' }])
    end

    it 'returns empty array when no sources' do
      message = build(:message, metadata: {})
      expect(message.sources).to eq([])
    end
  end
end
