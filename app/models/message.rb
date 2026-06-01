# frozen_string_literal: true

class Message < ApplicationRecord
  # 1. Module inclusions
  # (none)

  # 2. Constants
  # (none)

  # 3. Associations
  belongs_to :conversation, touch: true

  # 4. Enums
  enum :role,   { user: 0, assistant: 1, system: 2 }, validate: true
  enum :status, { pending: 0, streaming: 1, completed: 2, failed: 3 }, validate: true

  # 5. Validations
  # The `role` enum with `validate: true` already adds an inclusion validation;
  # we keep the explicit `validates :role, presence: true` because PROMPT.md
  # requires `validate_presence_of(:role)` in the spec.
  validates :role, presence: true

  # 6. Callbacks
  # (none)

  # 7. Scopes
  scope :completed, -> { where(status: :completed) }
  scope :visible,   -> { where(role: %i[user assistant]) }

  # 8. Class methods
  # (none)

  # 9. Public instance methods
  def append_content!(token)
    # Uses SQL concatenation to avoid a full AR reload on every streaming token.
    # This is a hot path — called once per streamed token.
    # rubocop:disable Rails/SkipsModelValidations
    # R4 (phase-2 plan): the spec explicitly verifies the SQL-concat hot path.
    # update_all is REQUIRED here — `update!` would reload the AR object and
    # defeat the purpose. The `quote` call protects against SQL injection.
    self.class.where(id: id).update_all("content = content || #{self.class.connection.quote(token)}")
    # rubocop:enable Rails/SkipsModelValidations
  end

  def sources
    metadata.fetch('sources', [])
  end

  def mark_failed!(error_message)
    update!(status: :failed, metadata: metadata.merge('error' => error_message))
  end

  # 10. private keyword
  # (none)

  # 11. Private instance methods
  # (none)
end
