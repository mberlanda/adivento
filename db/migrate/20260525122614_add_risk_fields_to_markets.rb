class AddRiskFieldsToMarkets < ActiveRecord::Migration[8.1]
  def change
    add_column :markets, :mechanism_type, :string, null: false, default: "fixed_odds"
    add_column :markets, :fee_bps, :integer, null: false, default: 100
    add_column :markets, :liability_cap_minor, :bigint, null: false, default: 100_000
  end
end
