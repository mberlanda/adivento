class CreateBetslipQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :betslip_quotes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :idempotency_key, null: false
      t.json :items, null: false, default: []
      t.bigint :total_stake_minor, null: false
      t.datetime :expires_at, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :betslip_quotes, :idempotency_key, unique: true
    add_index :betslip_quotes, :status
  end
end
