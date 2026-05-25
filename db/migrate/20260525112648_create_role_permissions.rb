class CreateRolePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :role_permissions do |t|
      t.string :role_name, null: false
      t.references :permission, null: false, foreign_key: true

      t.timestamps
    end

    add_index :role_permissions, [:role_name, :permission_id], unique: true
  end
end
