# frozen_string_literal: true

# Shared helpers for document pipeline specs.
module DocumentHelpers
  def build_chunk_hashes(count:, document: nil)
    doc = document || create(:document)
    Array.new(count) do |i|
      {
        document_id: doc.id,
        content: Faker::Lorem.paragraph,
        chunk_index: i,
        metadata: { char_start: i * 1800, char_end: (i + 1) * 1800 }.to_json,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
  end
end
