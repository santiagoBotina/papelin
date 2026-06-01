# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Conversations', type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  describe 'unauthenticated access' do
    it 'redirects to sign in for GET /conversations' do
      get conversations_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for GET /conversations/:id' do
      conversation = create(:conversation, user: user)
      get conversation_path(conversation)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for POST /conversations' do
      post conversations_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to sign in for DELETE /conversations/:id' do
      conversation = create(:conversation, user: user)
      delete conversation_path(conversation)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'authenticated access' do
    before { sign_in user }

    describe 'GET /conversations' do
      it 'returns 200 OK' do
        get conversations_path
        expect(response).to have_http_status(:ok)
      end

      it 'lists only the user\'s conversations' do
        create(:conversation, user: other)
        create(:conversation, user: user)
        get conversations_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'GET /conversations/:id' do
      it 'returns 200 OK when viewing own conversation' do
        conversation = create(:conversation, user: user)
        get conversation_path(conversation)
        expect(response).to have_http_status(:ok)
      end

      it 'redirects with error when viewing another user\'s conversation' do
        conversation = create(:conversation, user: other)
        get conversation_path(conversation)
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe 'POST /conversations' do
      it 'creates a conversation and redirects' do
        expect do
          post conversations_path
        end.to change(Conversation, :count).by(1)

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(conversation_path(Conversation.last))
      end
    end

    describe 'DELETE /conversations/:id' do
      it 'deletes own conversation and redirects' do
        conversation = create(:conversation, user: user)
        expect do
          delete conversation_path(conversation)
        end.to change(Conversation, :count).by(-1)

        expect(response).to redirect_to(conversations_path)
      end

      it 'redirects with error when deleting another user\'s conversation' do
        conversation = create(:conversation, user: other)
        expect do
          delete conversation_path(conversation)
        end.not_to change(Conversation, :count)

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to be_present
      end
    end
  end
end
