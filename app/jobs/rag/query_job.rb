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

      log_failure(result, assistant_message_id) unless result.success?
      broadcast_update(conversation, message)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn "Rag::QueryJob: message #{assistant_message_id} not found, skipping"
    end

    private

    def log_failure(result, message_id)
      Rails.logger.error "Rag::QueryJob failed for message #{message_id}: #{result.error}"
    end

    def broadcast_update(conversation, message)
      Turbo::StreamsChannel.broadcast_replace_to(
        "conversation_#{conversation.id}",
        target: ActionView::RecordIdentifier.dom_id(message),
        partial: 'messages/message',
        locals: { message: message.reload }
      )
    end
  end
end
