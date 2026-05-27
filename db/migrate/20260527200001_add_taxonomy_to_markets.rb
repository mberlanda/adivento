class AddTaxonomyToMarkets < ActiveRecord::Migration[8.1]
  def change
    add_column :markets, :category, :string, default: 'other', null: false
    add_column :markets, :tags, :json, default: [], null: false
    add_index :markets, :category
  end
end
