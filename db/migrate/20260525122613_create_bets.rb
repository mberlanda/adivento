class CreateBets < ActiveRecord::Migration[8.1]
  def change
    create_table :bets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :market, null: false, foreign_key: true
      t.references :market_leg, null: false, foreign_key: true
      t.bigint :stake_minor, null: false
      t.bigint :fee_minor, null: false
      t.bigint :net_stake_minor, null: false
      t.integer :odds_minor, null: false
      t.bigint :potential_payout_minor, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :bets, [:market_id, :status]
  end
end
