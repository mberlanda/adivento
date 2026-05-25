class CreateMarketTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :market_templates do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.text :default_legs
      t.integer :default_duration_hours, null: false, default: 24
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :market_templates, :key, unique: true
  end
end
