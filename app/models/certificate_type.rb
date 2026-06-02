# frozen_string_literal: true

class CertificateType < ApplicationRecord
  # Validations
  validates :key,   presence: true, uniqueness: true
  validates :label, presence: true

  # Scopes
  scope :active,   -> { where(active: true) }
  scope :ordered,  -> { order(:label) }

  # The 4 types that map to the CertificateRequest cert_type enum.
  SEED_TYPES = [
    { key: 'payroll',    label: 'Certificado de Nómina',    description: 'Ingresos y deducciones salariales' },
    { key: 'labor',      label: 'Certificado Laboral',       description: 'Relación laboral vigente con la empresa' },
    { key: 'employment', label: 'Carta de Empleo',           description: 'Carta oficial para bancos, visa, tramitación de visa, etc.' },
    { key: 'other',      label: 'Otro',                      description: 'Otra certificación emitida por RRHH' }
  ].freeze

  def self.seed!
    SEED_TYPES.each do |attrs|
      find_or_create_by!(key: attrs[:key]) do |ct|
        ct.label       = attrs[:label]
        ct.description = attrs[:description]
        ct.active      = false
      end
    end
  end
end
