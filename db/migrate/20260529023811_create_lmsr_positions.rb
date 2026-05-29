class CreateLmsrPositions < ActiveRecord::Migration[8.1]
  def change
    create_table :lmsr_positions do |t|
      t.references :user,   null: false, foreign_key: true
      t.references :market, null: false, foreign_key: true
      t.string  :side,      null: false
      t.bigint  :contracts, null: false, default: 0

      t.timestamps
    end

    add_index :lmsr_positions, %i[user_id market_id side], unique: true,
              name: 'index_lmsr_positions_on_user_market_side'
  end
end
