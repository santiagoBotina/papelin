# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Messages', type: :request do
  let(:user)         { create(:user) }
  let(:other)        { create(:user) }
  let(:conversation) { create(:conversation, user: user) }

  describe 'unauthenticated access' do
    it 'redirects to sign in for POST /conversations/:id/messages' do
      post conversation_messages_path(conversation), params: { message: { content: 'Hello' } }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'authenticated access' do
    before { sign_in user }

    describe 'POST /conversations/:conversation_id/messages' do
      let(:valid_params) { { message: { content: 'What documents do I need?' } } }

      it 'creates a user message and a pending assistant message' do
        expect do
          post conversation_messages_path(conversation), params: valid_params
        end.to change(Message, :count).by(2)

        expect(conversation.messages.where(role: :user).last.content).to eq('What documents do I need?')
        expect(conversation.messages.where(role: :assistant).last).to be_pending
      end

      it 'enqueues Rag::QueryJob' do
        expect do
          post conversation_messages_path(conversation), params: valid_params
        end.to have_enqueued_job(Rag::QueryJob)
      end

      it 'redirects to the conversation' do
        post conversation_messages_path(conversation), params: valid_params
        expect(response).to redirect_to(conversation_path(conversation))
      end

      it 'handle job enqueue with correct arguments' do
        assistant_message = nil
        expect do
          post conversation_messages_path(conversation), params: valid_params
          assistant_message = conversation.messages.where(role: :assistant).last
        end.to have_enqueued_job(Rag::QueryJob).with { |msg_id, content|
          expect(msg_id).to eq(assistant_message&.id)
          expect(content).to eq('What documents do I need?')
        }
      end

      context 'with empty content' do
        let(:empty_params) { { message: { content: '' } } }

        it 'does not create messages and redirects back to conversation' do
          expect do
            post conversation_messages_path(conversation), params: empty_params
          end.not_to change(Message, :count)

          expect(response).to redirect_to(conversation_path(conversation))
        end
      end
    end

    describe 'authorization' do
      it 'redirects with error when not the conversation owner' do
        other_conversation = create(:conversation, user: other)
        post conversation_messages_path(other_conversation),
             params: { message: { content: 'Hello' } }
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to be_present
      end
    end
  end
end
