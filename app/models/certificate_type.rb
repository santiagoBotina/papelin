# frozen_string_literal: true

class CertificateType < ApplicationRecord
  # Validations
  validates :key,   presence: true, uniqueness: { case_sensitive: false },
                    format: { with: /\A[a-z_]+\z/, message: 'solo minúsculas y guiones bajos' }
  validates :label, presence: true

  # Scopes
  scope :active,   -> { where(active: true) }
  scope :ordered,  -> { order(:label) }

  # The certificate types available for creation.
  SEED_TYPES = [
    { key: 'payroll',    label: 'Certificado de Nómina',
      description: 'Ingresos y deducciones salariales' },
    { key: 'labor',      label: 'Certificado Laboral',
      description: 'Relación laboral vigente con la empresa' },
    { key: 'recommendation', label: 'Carta de Recomendación',
      description: 'Carta de recomendación laboral para fines personales o profesionales' }
  ].freeze

  def associated_requests?
    CertificateRequest.exists?(cert_type: CertificateRequest.cert_types[key])
  end

  def self.seed!
    SEED_TYPES.each do |attrs|
      find_or_create_by!(key: attrs[:key]) do |ct|
        ct.label       = attrs[:label]
        ct.description = attrs[:description]
        ct.active      = true
      end
    end
  end
end
