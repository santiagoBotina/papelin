# frozen_string_literal: true

class CertificateRequest < ApplicationRecord
  # 1. Module inclusions
  # (none)

  # 2. Constants
  REFERENCE_YEAR_FORMAT = '%04d'
  REFERENCE_COUNTER_FORMAT = '%05d'
  REFERENCE_FORMAT = "CR-#{REFERENCE_YEAR_FORMAT}-#{REFERENCE_COUNTER_FORMAT}".freeze

  # 3. Associations
  belongs_to :user

  has_one_attached :generated_file

  # 4. Enums
  enum :cert_type, { payroll: 0, labor: 1, employment: 2, other: 3, recommendation: 4 }, validate: true
  enum :status,    { submitted: 0, in_review: 1, ready: 2, rejected: 3, delivered: 4 }, validate: true

  # 5. Validations
  validates :cert_type,        presence: true
  validates :requested_at,     presence: true
  validates :reference_number, presence: true, uniqueness: true
  validates :admin_notes,      length: { maximum: 1000 }, allow_blank: true
  # `belongs_to :user` adds an implicit presence validation; we keep an
  # explicit `validates :user, presence: true` removed to avoid the
  # Rails/RedundantPresenceValidationOnBelongsTo cop.

  # 6. Callbacks
  before_validation :assign_reference_number, on: :create

  # 7. Scopes
  scope :pending_for, lambda { |user|
    where(user: user).where.not(status: %i[delivered rejected])
  }
  scope :recent, -> { order(created_at: :desc) }

  # 8. Class methods

  # Returns the cert_type keys that are enabled by admin in the certificate_types table.
  def self.available_cert_types
    CertificateType.active.pluck(:key)
  end

  def self.generate_reference
    year    = Date.current.year
    counter = where(created_at: Date.current.beginning_of_year..).count + 1
    format(REFERENCE_FORMAT, year, counter)
  end

  # 9. Public instance methods
  def overdue?
    return false if ready? || delivered? || rejected?

    expected_ready_at.present? && expected_ready_at < Date.current
  end

  def human_status
    {
      'submitted' => 'Submitted — Under review',
      'in_review' => 'In Review',
      'ready' => 'Ready for download',
      'rejected' => 'Rejected',
      'delivered' => 'Delivered'
    }.fetch(status, status.humanize)
  end

  # 10. private keyword
  private

  # 11. Private instance methods
  def assign_reference_number
    self.reference_number ||= self.class.generate_reference
  end
end
