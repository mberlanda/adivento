class AddLastFillPriceCentsToMarkets < ActiveRecord::Migration[8.0]
  def change
    add_column :markets, :last_fill_price_cents, :integer
  end
end
