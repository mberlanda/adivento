class AddLmsrRealizedLossToMarkets < ActiveRecord::Migration[8.1]
  def change
    add_column :markets, :lmsr_realized_loss_minor, :bigint, default: 0, null: false
  end
end
