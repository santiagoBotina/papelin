# frozen_string_literal: true

class MessagesController < ApplicationController
  def create
    @conversation = Conversation.find(params[:conversation_id])
    authorize @conversation, :show?

    content = message_params[:content].to_s.strip
    return redirect_to @conversation if content.blank?

    create_user_message!(content)
    create_assistant_message!

    broadcast_messages
    Rag::QueryJob.perform_later(@assistant_message.id, content)

    redirect_to @conversation
  end

  private

  def create_user_message!(content)
    @user_message = @conversation.messages.create!(
      role: :user,
      content: content,
      status: :completed
    )
  end

  def create_assistant_message!
    @assistant_message = @conversation.messages.create!(
      role: :assistant,
      content: '',
      status: :pending
    )
  end

  def broadcast_messages
    stream_name = "conversation_#{@conversation.id}"
    [@user_message, @assistant_message].each do |msg|
      Turbo::StreamsChannel.broadcast_append_to(
        stream_name,
        target: 'messages',
        partial: 'messages/message',
        locals: { message: msg }
      )
    end
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
