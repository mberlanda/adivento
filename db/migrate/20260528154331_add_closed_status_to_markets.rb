class AddClosedStatusToMarkets < ActiveRecord::Migration[8.1]
  def up
    # Rails integer enum: draft=0, open=1, settled=2, cancelled=3, closed=4
    # Integer column already accepts value 4 — no column type change needed.
    execute <<~SQL
      ALTER TABLE markets
        ADD CONSTRAINT markets_closed_requires_close_at
        CHECK (status != 4 OR close_at IS NOT NULL);
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE markets
        DROP CONSTRAINT IF EXISTS markets_closed_requires_close_at;
    SQL
  end
end
