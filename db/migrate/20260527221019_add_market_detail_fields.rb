class AddMarketDetailFields < ActiveRecord::Migration[8.1]
  def change
    add_column :markets, :close_at, :datetime
    add_column :markets, :resolution_criteria, :text
    add_column :markets, :resolution_source, :string
  end
end
