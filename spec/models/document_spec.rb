# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Document, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:uploaded_by).class_name('User') }
    it { is_expected.to have_many(:chunks).class_name('DocumentChunk').dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:doc_type) }
    # R1 (phase-2 plan): see conversation_spec.rb — same fix for the
    # implicit `belongs_to` presence validation on the custom-named association.
    it { is_expected.to belong_to(:uploaded_by).required }
  end

  describe 'enums' do
    # rubocop:disable RSpec/ImplicitSubject
    # PROMPT.md §2.4 writes the enum assertion across two lines (with
    # `.with_values(...)` on the second line). The implicit `is_expected`
    # one-liner style would force an 80+ char line, so we keep the block
    # form and silence the cop.
    it {
      is_expected.to define_enum_for(:doc_type)
        .with_values(policy: 0, procedure: 1, faq: 2, template: 3)
    }

    it {
      is_expected.to define_enum_for(:status)
        .with_values(pending: 0, processing: 1, ready: 2, failed: 3)
    }
    # rubocop:enable RSpec/ImplicitSubject
  end

  describe 'scopes' do
    describe '.ready' do
      # rubocop:disable RSpec/MultipleExpectations
      # Verbatim from PROMPT.md §2.4: positive AND negative inclusion in one example.
      it 'returns only documents with status :ready' do
        ready      = create(:document, status: :ready)
        processing = create(:document, status: :processing)
        expect(described_class.ready).to include(ready)
        expect(described_class.ready).not_to include(processing)
      end
      # rubocop:enable RSpec/MultipleExpectations
    end
  end

  describe '#processing_duration' do
    it 'returns nil when not yet processed' do
      doc = build(:document, status: :pending)
      expect(doc.processing_duration).to be_nil
    end
  end
end
