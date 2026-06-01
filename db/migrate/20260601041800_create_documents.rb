class CreateDocuments < ActiveRecord::Migration[7.2]
  def change
    create_table :documents do |t|
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.string  :title,       null: false
      t.text    :description
      t.integer :doc_type,    null: false
      t.integer :status,      null: false, default: 0
      t.text    :processing_error
      t.integer :chunks_count, null: false, default: 0
      t.timestamps
    end

    add_index :documents, :status
    add_index :documents, :doc_type
    add_index :documents, [:uploaded_by_id, :created_at]
  end
end
