# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversation, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:messages).dependent(:destroy).order(:created_at) }
  end

  describe 'validations' do
    # R1 (phase-2 plan): the PROMPT.md uses `validate_presence_of(:user)` but
    # Rails 5+ auto-adds a presence validation to `belongs_to` that emits
    # "must exist" (not "can't be blank"). shoulda-matchers 7.x does NOT
    # accept that message; the error explicitly suggests `belong_to(...).required`.
    it { is_expected.to belong_to(:user).required }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(active: 0, archived: 1) }
  end

  describe 'scopes' do
    describe '.active' do
      # rubocop:disable RSpec/MultipleExpectations
      # Verbatim from PROMPT.md §2.2: positive AND negative inclusion in one example
      # is more readable than splitting.
      it 'returns only active conversations' do
        active   = create(:conversation, status: :active)
        archived = create(:conversation, status: :archived)
        expect(described_class.active).to include(active)
        expect(described_class.active).not_to include(archived)
      end
      # rubocop:enable RSpec/MultipleExpectations
    end

    describe '.recent' do
      it 'orders by created_at descending' do
        _older = create(:conversation, created_at: 2.days.ago)
        newer  = create(:conversation, created_at: 1.hour.ago)
        expect(described_class.recent.first).to eq(newer)
      end
    end
  end

  describe '#generate_title_from' do
    let(:conversation) { create(:conversation, title: nil) }

    it 'sets title to the first 60 chars of the given text' do
      conversation.generate_title_from('What are the required documents for a payroll certificate?')
      expect(conversation.title).to eq('What are the required documents for a payroll certificate?')
    end

    it 'truncates long text with ellipsis' do
      long_text = 'a' * 100
      conversation.generate_title_from(long_text)
      expect(conversation.title.length).to be <= 63 # 60 chars + "..."
    end

    it 'does not overwrite an existing title' do
      conversation.update!(title: 'Existing Title')
      conversation.generate_title_from('New text')
      expect(conversation.reload.title).to eq('Existing Title')
    end
  end
end
