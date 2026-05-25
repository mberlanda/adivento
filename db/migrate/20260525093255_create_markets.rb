class CreateMarkets < ActiveRecord::Migration[8.1]
  def change
    create_table :markets do |t|
      t.string :question, null: false
      t.text :description, null: false
      t.integer :status, null: false, default: 0
      t.boolean :structure_locked, null: false, default: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :settled_by, null: true, foreign_key: { to_table: :users }
      t.string :settled_outcome

      t.timestamps
    end

    add_index :markets, :status
  end
end
