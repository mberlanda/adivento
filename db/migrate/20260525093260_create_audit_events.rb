class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.text :reason
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :audit_events, [:target_type, :target_id]
    add_index :audit_events, :action
  end
end
