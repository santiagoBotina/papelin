# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificateRequestPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:employee) { create(:user) }
  let(:other)    { create(:user) }
  let(:admin)    { create(:user, :admin) }

  describe 'read access' do
    permissions :index? do
      it 'permits employees (scope filters to their own)' do
        expect(policy).to permit(employee, CertificateRequest)
      end

      it 'permits admins (scope returns all)' do
        expect(policy).to permit(admin, CertificateRequest)
      end
    end

    permissions :show? do
      it 'permits the owner to view their own request' do
        request = create(:certificate_request, user: employee)
        expect(policy).to permit(employee, request)
      end

      it 'denies another employee from viewing a non-owned request' do
        request = create(:certificate_request, user: other)
        expect(policy).not_to permit(employee, request)
      end

      it 'permits admins to view any request' do
        request = create(:certificate_request, user: other)
        expect(policy).to permit(admin, request)
      end
    end
  end

  describe 'create access' do
    permissions :create? do
      it 'permits employees to file a new request' do
        expect(policy).to permit(employee, CertificateRequest)
      end

      it 'permits admins (operational filing)' do
        expect(policy).to permit(admin, CertificateRequest)
      end
    end
  end

  describe 'update access (HR manages status changes)' do
    permissions :update? do
      it 'denies employees from updating their own status' do
        request = create(:certificate_request, user: employee)
        expect(policy).not_to permit(employee, request)
      end

      it 'denies employees from updating another user\'s request' do
        request = create(:certificate_request, user: other)
        expect(policy).not_to permit(employee, request)
      end

      it 'permits admins to update any request status' do
        request = create(:certificate_request, user: other)
        expect(policy).to permit(admin, request)
      end
    end
  end

  describe 'destroy access (records are permanent)' do
    permissions :destroy? do
      it 'denies admins from destroying a request' do
        request = create(:certificate_request, user: employee)
        expect(policy).not_to permit(admin, request)
      end

      it 'denies employees from destroying a request' do
        request = create(:certificate_request, user: employee)
        expect(policy).not_to permit(employee, request)
      end
    end
  end

  describe 'Scope#resolve' do
    before do
      create(:certificate_request, user: employee)
      create(:certificate_request, user: other)
      create(:certificate_request, user: admin)
    end

    it 'returns the employee\'s own requests' do
      scope = Pundit.policy_scope!(employee, CertificateRequest)
      expect(scope.pluck(:user_id).uniq).to eq([employee.id])
    end

    it 'never returns another user\'s requests to an employee' do
      scope = Pundit.policy_scope!(employee, CertificateRequest)
      expect(scope.where.not(user_id: employee.id)).to be_empty
    end

    it 'returns every request to admins' do
      scope = Pundit.policy_scope!(admin, CertificateRequest)
      expect(scope.count).to eq(CertificateRequest.count)
    end
  end
end
