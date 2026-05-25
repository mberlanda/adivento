class CreateLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :entry_type, null: false
      t.bigint :amount_minor, null: false
      t.string :direction, null: false
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :ledger_entries, :entry_type
  end
end
