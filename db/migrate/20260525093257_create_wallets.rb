class CreateWallets < ActiveRecord::Migration[8.1]
  def change
    create_table :wallets do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :asset_code, null: false, default: "ADIV"
      t.bigint :available_minor, null: false, default: 0
      t.bigint :reserved_minor, null: false, default: 0

      t.timestamps
    end
  end
end
