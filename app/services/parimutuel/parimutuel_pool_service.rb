module Parimutuel
  class ParimutuelPoolService
    Result = Struct.new(:success?, :errors, keyword_init: true)

    def self.add_stake(market:, user:, side:, stake_minor:)
      ApplicationRecord.transaction do
        raise "Market is not open" unless market.open?

        wallet = user.wallet.lock!
        raise "Insufficient funds" if wallet.available_minor < stake_minor

        wallet.update!(available_minor: wallet.available_minor - stake_minor)

        LedgerEntry.create!(
          user: user, actor: user,
          entry_type: "PARIMUTUEL_STAKE", direction: "debit",
          amount_minor: stake_minor
        )

        pool_column = side == "YES" ? :parimutuel_pool_yes_minor : :parimutuel_pool_no_minor
        market.lock!
        market.increment!(pool_column, stake_minor)

        AuditEvent.create!(
          action: "parimutuel.stake",
          actor: user,
          target_type: "Market", target_id: market.id,
          metadata: { side: side, stake_minor: stake_minor }
        )

        HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: "parimutuel.stake") if defined?(HotStorage::MarketSnapshotProjector)

        Result.new(success?: true, errors: [])
      end
    rescue => e
      Result.new(success?: false, errors: [e.message])
    end

    def self.yes_probability(market)
      total = market.parimutuel_pool_yes_minor + market.parimutuel_pool_no_minor
      return 50.0 if total.zero?
      (market.parimutuel_pool_yes_minor.to_f / total * 100).round(4)
    end

    def self.no_probability(market) = (100 - yes_probability(market)).round(4)
  end
end
