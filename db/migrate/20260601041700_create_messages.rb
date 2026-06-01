class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.integer :role,    null: false
      t.text    :content, null: false, default: ""
      t.jsonb   :metadata, null: false, default: {}
      t.integer :status,  null: false, default: 0
      t.timestamps
    end

    add_index :messages, [:conversation_id, :created_at]
    add_index :messages, [:conversation_id, :role]
  end
end
