class CreatePriceSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :price_snapshots do |t|
      t.bigint   :market_id,      null: false
      t.string   :mechanism_type, null: false
      t.json     :snapshot_data,  null: false, default: {}
      t.datetime :recorded_at,    null: false
      t.timestamps
    end
    add_index :price_snapshots, [:market_id, :recorded_at]
    add_foreign_key :price_snapshots, :markets
  end
end
