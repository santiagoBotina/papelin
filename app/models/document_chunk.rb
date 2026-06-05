# frozen_string_literal: true

class DocumentChunk < ApplicationRecord
  # 1. Module inclusions
  # `has_neighbors` (from the `neighbor` gem) adds class methods for
  # approximate-nearest-neighbor search and an instance method to read
  # the distance of the most recent neighbor query. See:
  # https://github.com/ankane/neighbor
  # 2. Constants
  # (none)

  # 3. Associations
  belongs_to :document

  has_neighbors :embedding

  # 4. Enums
  # (none)

  # 5. Validations
  validates :content,     presence: true
  validates :chunk_index, presence: true,
                          numericality: { greater_than_or_equal_to: 0 }

  # 6. Callbacks
  # (none)

  # 7. Scopes
  scope :ready, -> { for_ready_documents }

  # 8. Class methods
  def self.for_ready_documents
    eager_load(:document).where(documents: { status: Document.statuses[:ready] })
  end

  # 9. Public instance methods
  def source_title
    document.title
  end

  # 10. private keyword
  # (none)

  # 11. Private instance methods
  # (none)
end
