# frozen_string_literal: true

class MessagesController < ApplicationController
  def create
    @conversation = Conversation.find(params[:conversation_id])
    authorize @conversation

    @user_message = @conversation.messages.create!(
      role: :user,
      content: message_params[:content],
      status: :completed
    )

    @assistant_message = @conversation.messages.create!(
      role: :assistant,
      content: '',
      status: :pending
    )

    Rag::QueryJob.perform_later(@assistant_message.id, message_params[:content])

    redirect_to @conversation
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
