class CreateFaucetRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :faucet_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :amount_minor, null: false
      t.integer :status, null: false, default: 0
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.text :note

      t.timestamps
    end

    add_index :faucet_requests, :status
  end
end
