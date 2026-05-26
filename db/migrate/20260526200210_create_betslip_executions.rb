class CreateBetslipExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :betslip_executions do |t|
      t.references :betslip_quote, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true
      t.json :bet_ids, null: false, default: []
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
