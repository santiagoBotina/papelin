# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationPolicy, type: :policy do
  subject(:policy) { described_class }

  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let(:admin) { create(:user, :admin) }

  permissions :show?, :update?, :destroy? do
    context 'when the user owns the conversation' do
      it 'grants access to the owner' do
        conversation = create(:conversation, user: user)
        expect(policy).to permit(user, conversation)
      end

      it 'grants access to an admin' do
        conversation = create(:conversation, user: other)
        expect(policy).to permit(admin, conversation)
      end
    end

    context 'when the user does not own the conversation' do
      it 'denies access to a non-owner non-admin' do
        conversation = create(:conversation, user: other)
        expect(policy).not_to permit(user, conversation)
      end
    end
  end

  permissions :index?, :create? do
    it 'grants access to any authenticated user' do
      expect(policy).to permit(user, Conversation)
    end

    it 'grants access to admins' do
      expect(policy).to permit(admin, Conversation)
    end
  end

  describe 'Scope#resolve' do
    let!(:own)        { create(:conversation, user: user) }
    let!(:other_conv) { create(:conversation, user: other) }

    it 'returns only conversations belonging to the user' do
      scope = Pundit.policy_scope!(user, Conversation)
      expect(scope).to include(own)
    end

    it 'excludes other users\' conversations from the employee scope' do
      scope = Pundit.policy_scope!(user, Conversation)
      expect(scope).not_to include(other_conv)
    end

    it 'returns all conversations to an admin' do
      scope = Pundit.policy_scope!(admin, Conversation)
      expect(scope).to include(own, other_conv)
    end
  end
end
