# frozen_string_literal: true

module Rag
  class QueryJob < ApplicationJob
    queue_as :default

    retry_on Faraday::TimeoutError, wait: 5.seconds, attempts: 2
    retry_on Faraday::ServerError,  wait: 5.seconds, attempts: 2
    discard_on ActiveJob::DeserializationError

    def perform(assistant_message_id, user_content)
      message = Message.find(assistant_message_id)

      # Idempotency guard — skip if already completed or failed
      return if message.completed? || message.failed?

      conversation = message.conversation
      user = conversation.user

      result = Rag::QueryService.call(
        conversation: conversation,
        user_message: user_content,
        user: user,
        assistant_message: message
      )

      if result.success?
        # Broadcast the completed assistant message, replacing the loading bubble
        Turbo::StreamsChannel.broadcast_replace_to(
          "conversation_#{conversation.id}",
          target: ActionView::RecordIdentifier.dom_id(message),
          partial: 'messages/message',
          locals: { message: message.reload }
        )
      else
        Rails.logger.error "Rag::QueryJob failed for message #{assistant_message_id}: #{result.error}"
        # Broadcast the failed state too so the UI updates
        Turbo::StreamsChannel.broadcast_replace_to(
          "conversation_#{conversation.id}",
          target: ActionView::RecordIdentifier.dom_id(message),
          partial: 'messages/message',
          locals: { message: message.reload }
        )
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn "Rag::QueryJob: message #{assistant_message_id} not found, skipping"
    end
  end
end
