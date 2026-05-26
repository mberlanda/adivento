class AddLegCountTriggerToMarkets < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION check_market_leg_count()
      RETURNS TRIGGER AS $$
      BEGIN
        IF (SELECT COUNT(*) FROM market_legs WHERE market_id = NEW.market_id) > 2 THEN
          RAISE EXCEPTION 'Market % already has 2 legs', NEW.market_id;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER enforce_max_two_market_legs
      BEFORE INSERT ON market_legs
      FOR EACH ROW EXECUTE FUNCTION check_market_leg_count();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS enforce_max_two_market_legs ON market_legs;
      DROP FUNCTION IF EXISTS check_market_leg_count();
    SQL
  end
end
