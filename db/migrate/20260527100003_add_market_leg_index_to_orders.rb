class AddMarketLegIndexToOrders < ActiveRecord::Migration[8.0]
  def change
    add_index :orders, :market_leg_id
  end
end
