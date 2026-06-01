class CreateConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :title
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :conversations, [:user_id, :status]
    add_index :conversations, [:user_id, :created_at]
  end
end
