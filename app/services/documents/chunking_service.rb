# frozen_string_literal: true

module Documents
  # Splits plain text into fixed-size overlapping chunks for embedding.
  #
  # Constants:
  #   CHUNK_SIZE    = 2000 characters
  #   CHUNK_OVERLAP = 200 characters
  #
  # Returns an array of hash-like records ready for DocumentChunk.insert_all.
  class ChunkingService
    CHUNK_SIZE    = 2000
    CHUNK_OVERLAP = 200

    def self.call(text:, document:)
      new(text: text, document: document).call
    end

    def initialize(text:, document:)
      @text = text
      @document = document
    end

    def call
      return [] if @text.blank?

      text_length = @text.length
      step = CHUNK_SIZE - CHUNK_OVERLAP

      build_chunks(text_length, step)
    end

    private

    def build_chunks(text_length, step)
      chunks = []
      start = 0
      index = 0

      while start < text_length
        finish = [start + CHUNK_SIZE, text_length].min
        content = @text[start...finish].strip
        next if content.blank?

        chunks << build_chunk(content, start, finish, index)
        start += step
        index += 1
      end

      chunks
    end

    def build_chunk(content, char_start, char_end, index)
      {
        document_id: @document.id,
        content: content,
        chunk_index: index,
        metadata: { char_start: char_start, char_end: char_end }.to_json,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
  end
end
