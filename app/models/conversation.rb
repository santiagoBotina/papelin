# frozen_string_literal: true

class Conversation < ApplicationRecord
  # 1. Module inclusions
  # (none)

  # 2. Constants
  TITLE_MAX_LENGTH = 60

  # 3. Associations
  belongs_to :user
  has_many :messages, -> { order(:created_at) }, dependent: :destroy, inverse_of: :conversation

  # 4. Enums
  enum :status, { active: 0, archived: 1 }, validate: true

  # 5. Validations

  # 6. Callbacks
  # (none)

  # 7. Scopes
  scope :active, -> { where(status: :active) }
  scope :recent, -> { order(created_at: :desc) }

  # 8. Class methods
  # (none)

  # 9. Public instance methods
  def generate_title_from(text)
    return if title.present?

    update!(title: text.to_s.truncate(TITLE_MAX_LENGTH))
  end

  def context_messages(limit: 10)
    messages.where(role: %i[user assistant]).last(limit)
  end

  # 10. private keyword
  # (none)

  # 11. Private instance methods
  # (none)
end
