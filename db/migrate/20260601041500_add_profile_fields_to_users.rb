class AddProfileFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :first_name,  :string,  null: false, default: ""
    add_column :users, :last_name,   :string,  null: false, default: ""
    add_column :users, :role,        :integer, null: false, default: 0
    add_column :users, :employee_id, :string,  null: false, default: ""

    add_index :users, :employee_id, unique: true
  end
end
