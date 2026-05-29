class AddDirectionToOrders < ActiveRecord::Migration[8.1]
  def up
    add_column :orders, :direction, :string, null: false, default: 'buy'
    add_check_constraint :orders, "direction IN ('buy', 'sell')", name: 'orders_direction_valid'
  end

  def down
    remove_check_constraint :orders, name: 'orders_direction_valid'
    remove_column :orders, :direction
  end
end
