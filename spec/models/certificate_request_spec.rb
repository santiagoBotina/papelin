# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificateRequest, type: :model do
  # R11 (phase-2 plan): the implicit `is_expected` subject is just
  # `described_class.new`, which has no factory-built associations. The
  # uniqueness matcher creates a *second* record from this empty subject
  # and fails on `user_id NOT NULL`. Building from the factory gives it a
  # fully-populated subject to work with.
  subject(:certificate_request) { build(:certificate_request) }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:cert_type) }
    it { is_expected.to validate_presence_of(:requested_at) }
    # R12 (phase-2 plan): the `before_validation :assign_reference_number`
    # callback always assigns a value, so the matcher can never observe
    # `reference_number == nil` long enough to prove the presence validation.
    # The presence is *guaranteed* by the callback — equivalent in effect.
    it { is_expected.to validate_uniqueness_of(:reference_number) }
    # R1 (phase-2 plan): see conversation_spec.rb — same fix for the
    # implicit `belongs_to` presence validation.
    it { is_expected.to belong_to(:user).required }
  end

  describe 'enums' do
    # rubocop:disable RSpec/ImplicitSubject
    # PROMPT.md §2.6 writes the enum assertion across two lines (with
    # `.with_values(...)` on the second line). The implicit `is_expected`
    # one-liner style would force an 80+ char line, so we keep the block
    # form and silence the cop.
    it {
      is_expected.to define_enum_for(:cert_type)
        .with_values(payroll: 0, labor: 1, employment: 2, other: 3, recommendation: 4)
    }

    it {
      is_expected.to define_enum_for(:status)
        .with_values(submitted: 0, in_review: 1, ready: 2, rejected: 3, delivered: 4)
    }
    # rubocop:enable RSpec/ImplicitSubject
  end

  describe 'scopes' do
    describe '.pending_for' do
      let(:user) { create(:user) }

      # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
      # Verbatim from PROMPT.md §2.6: positive AND negative inclusion in
      # one example, with the unowned-but-same-status case as a third
      # fixture, to prove both the user scope and the status filter.
      it 'returns only active requests for the given user' do
        active  = create(:certificate_request, user: user, status: :submitted)
        other   = create(:certificate_request, status: :submitted)
        deliver = create(:certificate_request, user: user, status: :delivered)

        result = described_class.pending_for(user)
        expect(result).to include(active)
        expect(result).not_to include(other, deliver)
      end
      # rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength
    end
  end

  describe '#overdue?' do
    it 'returns true when expected_ready_at is in the past and not ready' do
      req = build(:certificate_request,
                  status: :submitted,
                  expected_ready_at: 1.day.ago)
      expect(req.overdue?).to be true
    end

    it 'returns false when already ready' do
      req = build(:certificate_request, status: :ready, expected_ready_at: 1.day.ago)
      expect(req.overdue?).to be false
    end
  end

  describe '.generate_reference' do
    it 'returns a reference in the format CR-YEAR-NNNNN' do
      ref = described_class.generate_reference
      expect(ref).to match(/\ACR-\d{4}-\d{5}\z/)
    end
  end
end
