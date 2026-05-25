class CreateMarketLegs < ActiveRecord::Migration[8.1]
  def change
    create_table :market_legs do |t|
      t.references :market, null: false, foreign_key: true
      t.string :label, null: false
      t.integer :odds_minor, null: false, default: 5000
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :market_legs, [:market_id, :label], unique: true
  end
end
