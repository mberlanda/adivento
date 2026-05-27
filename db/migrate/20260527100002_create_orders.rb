class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.bigint  :market_id,           null: false
      t.bigint  :market_leg_id,       null: false
      t.bigint  :user_id,             null: false
      t.string  :side,                null: false             # YES | NO
      t.integer :price_cents,         null: false             # 1..99
      t.integer :quantity,            null: false             # > 0
      t.integer :filled_quantity,     null: false, default: 0
      t.integer :cancelled_quantity,  null: false, default: 0
      t.integer :status,              null: false, default: 0 # enum
      t.integer :time_in_force,       null: false, default: 0 # enum
      t.timestamps
    end

    add_index :orders, :market_id
    add_index :orders, :user_id
    add_index :orders, [:market_id, :side, :price_cents, :status], name: "index_orders_book"
    add_foreign_key :orders, :markets
    add_foreign_key :orders, :users
    add_foreign_key :orders, :market_legs
  end
end
