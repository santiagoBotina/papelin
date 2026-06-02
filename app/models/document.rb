# frozen_string_literal: true

class Document < ApplicationRecord
  # 1. Module inclusions
  # (none)

  # 2. Constants
  ALLOWED_FILE_CONTENT_TYPES = %w[
    application/pdf
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    text/plain
    text/markdown
  ].freeze
  MAX_FILE_SIZE = 20.megabytes
  PROCESSING_ERROR_MAX_LENGTH = 2000

  # 3. Associations
  belongs_to :uploaded_by, class_name: 'User'
  has_many   :chunks, class_name: 'DocumentChunk', dependent: :destroy

  has_one_attached :file

  # 4. Enums
  enum :doc_type, { policy: 0, procedure: 1, faq: 2, template: 3 }, validate: true
  enum :status,   { pending: 0, processing: 1, ready: 2, failed: 3 }, validate: true

  # 5. Validations
  validates :title,    presence: true
  validates :doc_type, presence: true
  # `belongs_to :uploaded_by` already adds an implicit presence validation;
  # `validates :uploaded_by, presence: true` would be redundant (and is
  # flagged by Rails/RedundantPresenceValidationOnBelongsTo).
  # rubocop:disable Rails/I18nLocaleTexts
  # Validation messages are verbatim from PROMPT.md §2.4 / AGENTS.md §8; the
  # i18n extraction refactor is scheduled for Phase 9 (test infrastructure).
  validates :file,
            content_type: { in: ALLOWED_FILE_CONTENT_TYPES,
                            message: 'must be a PDF, Word document, or plain text file' },
            size: { less_than: MAX_FILE_SIZE, message: 'must be less than 20MB' },
            if: -> { file.attached? }
  # rubocop:enable Rails/I18nLocaleTexts

  # 6. Callbacks
  # (none)

  # 7. Scopes
  scope :ready,   -> { where(status: :ready) }
  scope :recent,  -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(doc_type: type) }

  # 8. Class methods
  # (none)

  # 9. Public instance methods
  def processing_duration
    return nil unless ready? || failed?

    (updated_at - created_at).round
  end

  def fail!(error)
    update!(status: :failed, processing_error: error.to_s.truncate(PROCESSING_ERROR_MAX_LENGTH))
  end

  # 10. private keyword
  # (none)

  # 11. Private instance methods
  # (none)
end
