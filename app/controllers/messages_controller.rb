# frozen_string_literal: true

class MessagesController < ApplicationController
  def create
    @conversation = Conversation.find(params[:conversation_id])
    authorize @conversation

    content = message_params[:content].to_s.strip
    return redirect_to @conversation if content.blank?

    @user_message = @conversation.messages.create!(
      role: :user,
      content: content,
      status: :completed
    )

    @assistant_message = @conversation.messages.create!(
      role: :assistant,
      content: '',
      status: :pending
    )

    # Broadcast both messages immediately so the UI updates before the job finishes
    stream_name = "conversation_#{@conversation.id}"
    Turbo::StreamsChannel.broadcast_append_to(
      stream_name,
      target: 'messages',
      partial: 'messages/message',
      locals: { message: @user_message }
    )
    Turbo::StreamsChannel.broadcast_append_to(
      stream_name,
      target: 'messages',
      partial: 'messages/message',
      locals: { message: @assistant_message }
    )

    Rag::QueryJob.perform_later(@assistant_message.id, content)

    redirect_to @conversation
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
