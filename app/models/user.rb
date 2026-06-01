# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { employee: 0, admin: 1 }, validate: true

  has_many :conversations, dependent: :destroy
  has_many :documents, foreign_key: :uploaded_by_id, dependent: :nullify,
           inverse_of: :uploaded_by
  has_many :certificate_requests, dependent: :nullify

  validates :first_name,  presence: true
  validates :last_name,   presence: true
  validates :employee_id, presence: true, uniqueness: { case_sensitive: false }

  scope :admins,    -> { where(role: :admin) }
  scope :employees, -> { where(role: :employee) }

  def display_name
    full = "#{first_name} #{last_name}".strip
    full.presence || email
  end

  def active_certificate_requests
    certificate_requests.where.not(status: %i[delivered rejected])
  end
end
