class AddMechanismColumnsToMarkets < ActiveRecord::Migration[8.1]
  def change
    add_column :markets, :taker_fee_bps, :integer
    add_column :markets, :liquidity_subsidy_minor, :bigint
    add_column :markets, :spread_fee_bps, :integer
    add_column :markets, :takeout_bps, :integer

    # LMSR runtime state
    add_column :markets, :lmsr_b_parameter, :float
    add_column :markets, :lmsr_q_yes, :bigint, default: 0, null: false
    add_column :markets, :lmsr_q_no,  :bigint, default: 0, null: false

    # Parimutuel pool state
    add_column :markets, :parimutuel_pool_yes_minor, :bigint, default: 0, null: false
    add_column :markets, :parimutuel_pool_no_minor,  :bigint, default: 0, null: false
  end
end
