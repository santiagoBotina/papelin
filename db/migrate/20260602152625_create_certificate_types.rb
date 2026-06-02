class CreateCertificateTypes < ActiveRecord::Migration[7.2]
  def change
    create_table :certificate_types do |t|
      t.string  :key,         null: false
      t.string  :label,       null: false
      t.text    :description
      t.boolean :active,      null: false, default: false

      t.timestamps
    end

    add_index :certificate_types, :key,    unique: true
    add_index :certificate_types, :active
  end
end
