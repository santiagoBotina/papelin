class CreateCertificateRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :certificate_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.integer    :cert_type,         null: false
      t.integer    :status,            null: false, default: 0
      t.date       :requested_at,      null: false
      t.date       :expected_ready_at
      t.date       :ready_at
      t.text       :notes
      t.string     :reference_number,  null: false
      t.timestamps
    end

    add_index :certificate_requests, :reference_number, unique: true
    add_index :certificate_requests, [:user_id, :status]
    add_index :certificate_requests, [:user_id, :cert_type]
    add_index :certificate_requests, :status
  end
end
