# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:employee) { create(:user) }
  let(:admin)    { create(:user, :admin) }

  describe 'read access' do
    let(:document) { create(:document, :ready) }

    permissions :index?, :show? do
      it 'permits employees to list and view' do
        expect(policy).to permit(employee, document)
      end

      it 'permits admins to list and view' do
        expect(policy).to permit(admin, document)
      end
    end
  end

  describe 'write access' do
    let(:document) { create(:document, :ready) }

    permissions :create?, :update?, :destroy? do
      it 'permits admins to manage the document lifecycle' do
        expect(policy).to permit(admin, document)
      end

      it 'denies employees from managing the document lifecycle' do
        expect(policy).not_to permit(employee, document)
      end
    end
  end

  describe 'Scope#resolve' do
    before do
      create(:document, :ready)
      create(:document, :processing)
      create(:document, :pending)
    end

    let!(:ready_doc)      { Document.find_by(status: 'ready') }
    let!(:processing_doc) { Document.find_by(status: 'processing') }
    let!(:pending_doc)    { Document.find_by(status: 'pending') }

    it 'returns all documents to admins' do
      scope = Pundit.policy_scope!(admin, Document)
      expect(scope.count).to eq(Document.count)
    end

    it 'includes documents of every status in the admin scope' do
      scope = Pundit.policy_scope!(admin, Document)
      expect(scope).to include(ready_doc, processing_doc, pending_doc)
    end

    it 'only returns ready documents to employees' do
      scope = Pundit.policy_scope!(employee, Document)
      expect(scope.pluck(:status).uniq).to eq(['ready'])
    end

    it 'excludes non-ready documents from the employee scope' do
      scope = Pundit.policy_scope!(employee, Document)
      expect(scope).not_to include(processing_doc, pending_doc)
    end
  end
end
