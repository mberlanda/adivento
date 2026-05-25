class CreateUserGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :user_grants do |t|
      t.references :user, null: false, foreign_key: true
      t.references :permission, null: false, foreign_key: true
      t.boolean :allow, null: false
      t.text :reason
      t.references :granted_by, null: false, foreign_key: { to_table: :users }
      t.datetime :expires_at

      t.timestamps
    end

    add_index :user_grants, [:user_id, :permission_id, :created_at]
  end
end
