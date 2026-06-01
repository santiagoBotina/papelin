# frozen_string_literal: true

module Rag
  class QueryService
    Result = Struct.new(:success?, :message, :error, keyword_init: true)

    def self.call(conversation:, user_message:, user:, assistant_message:)
      new(conversation: conversation, user_message: user_message, user: user,
          assistant_message: assistant_message).call
    end

    def initialize(conversation:, user_message:, user:, assistant_message:)
      @conversation = conversation
      @user_message = user_message
      @user = user
      @assistant_message = assistant_message
    end

    def call
      @assistant_message.update!(status: :streaming)

      embed = embed_query
      return mark_failed!(embed.error) unless embed.success?

      retrieval = retrieve(embed.embedding)
      return mark_failed!(retrieval.error) unless retrieval.success?

      generation = generate(retrieval.chunks)
      return mark_failed!(generation.error) unless generation.success?

      persist_success!(generation, retrieval.chunks)
      @conversation.generate_title_from(@user_message)

      Result.new(success?: true, message: @assistant_message, error: nil)
    end

    private

    def embed_query
      Rag::EmbedService.call(text: @user_message)
    end

    def retrieve(query_embedding)
      Rag::RetrievalService.call(query_embedding: query_embedding)
    end

    def generate(chunks)
      Rag::GenerationService.call(
        conversation: @conversation,
        chunks: chunks,
        user_message: @user_message,
        user: @user,
        assistant_message: @assistant_message
      )
    end

    def persist_success!(generation, chunks)
      @assistant_message.update!(
        content: generation.content,
        status: :completed,
        metadata: {
          sources: chunks.map(&:source_title),
          token_usage: generation.metadata[:token_usage]
        }
      )
    end

    def mark_failed!(error)
      @assistant_message.mark_failed!(error)
      Result.new(success?: false, message: @assistant_message, error: error)
    end
  end
end
