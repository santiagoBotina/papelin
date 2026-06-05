# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'devise modules' do
    it { is_expected.to validate_presence_of(:email).with_message("can't be blank") }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:password) }

    it 'validates minimum password length' do
      user = build(:user, password: 'short')
      user.valid?
      expect(user.errors[:password]).to include('is too short (minimum is 6 characters)')
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:employee_id) }
    it { is_expected.to validate_uniqueness_of(:employee_id).case_insensitive }
  end

  describe 'associations' do
    it { is_expected.to have_many(:conversations).dependent(:destroy) }
    it { is_expected.to have_many(:documents).with_foreign_key(:uploaded_by_id).dependent(:nullify) }
    it { is_expected.to have_many(:certificate_requests).dependent(:nullify) }
  end

  describe 'enums' do
    subject(:user) { build(:user) }

    it do
      expect(user).to define_enum_for(:role)
        .with_values(employee: 0, admin: 1)
        .backed_by_column_of_type(:integer)
    end
  end

  describe 'scopes' do
    let!(:employee_user) { create(:user, role: :employee) }
    let!(:admin_user)    { create(:user, :admin) }

    describe '.admins' do
      it 'includes admin users' do
        expect(described_class.admins).to include(admin_user)
      end

      it 'excludes employee users' do
        expect(described_class.admins).not_to include(employee_user)
      end
    end

    describe '.employees' do
      it 'includes employee users' do
        expect(described_class.employees).to include(employee_user)
      end

      it 'excludes admin users' do
        expect(described_class.employees).not_to include(admin_user)
      end
    end
  end

  describe '#display_name' do
    subject(:name) { user.display_name }

    context 'when first_name and last_name are present' do
      let(:user) { build(:user, first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com') }

      it { is_expected.to eq('Jane Doe') }
    end

    context 'when first_name is blank' do
      let(:user) { build(:user, first_name: '', last_name: 'Doe', email: 'jane@example.com') }

      it { is_expected.to eq('Doe') }
    end

    context 'when both first_name and last_name are blank' do
      let(:user) { build(:user, first_name: '', last_name: '', email: 'jane@example.com') }

      it { is_expected.to eq('jane@example.com') }
    end
  end

  describe '#active_certificate_requests' do
    let(:user) { create(:user) }

    let!(:requests) do
      {
        submitted: create(:certificate_request, user: user, status: :submitted),
        in_review: create(:certificate_request, user: user, status: :in_review),
        ready: create(:certificate_request, user: user, status: :ready),
        rejected: create(:certificate_request, user: user, status: :rejected),
        delivered: create(:certificate_request, user: user, status: :delivered)
      }
    end

    it 'includes submitted requests' do
      expect(user.active_certificate_requests).to include(requests[:submitted])
    end

    it 'includes in_review requests' do
      expect(user.active_certificate_requests).to include(requests[:in_review])
    end

    it 'includes ready requests' do
      expect(user.active_certificate_requests).to include(requests[:ready])
    end

    it 'excludes rejected requests' do
      expect(user.active_certificate_requests).not_to include(requests[:rejected])
    end

    it 'excludes delivered requests' do
      expect(user.active_certificate_requests).not_to include(requests[:delivered])
    end

    it 'returns only requests belonging to the user' do
      other_user = create(:user)
      other_request = create(:certificate_request, user: other_user, status: :submitted)
      expect(user.active_certificate_requests).not_to include(other_request)
    end
  end
end
