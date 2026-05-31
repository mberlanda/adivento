class MarketCancellationService
  class InvalidCancellation < StandardError; end

  Result = Struct.new(:success?, :refunded_total_minor, :clawed_back_minor,
                      :clawback_shortfall_minor, :errors, keyword_init: true)

  def self.call(**) = new(**).call

  def initialize(market:, actor:, reason:)
    @market = market
    @actor = actor
    @reason = reason.to_s.strip
    @refunded_minor = 0
    @clawed_back_minor = 0
    @clawback_shortfall_minor = 0
  end

  def call
    raise InvalidCancellation, 'Reason is required (min 10 characters)' if @reason.length < 10

    ApplicationRecord.transaction do
      m = Market.lock.find(@market.id)
      raise InvalidCancellation, 'Market cannot be cancelled' unless m.open? || m.closed?

      refund_fixed_odds!(m) if m.fixed_odds?
      refund_parimutuel!(m) if m.parimutuel?
      refund_lmsr!(m)       if m.lmsr?
      refund_clob!(m)       if m.clob?

      m.update!(status: :cancelled)
      AuditEvent.create!(
        actor: @actor, action: 'market.cancel',
        target_type: 'Market', target_id: m.id,
        metadata: {
          mechanism: m.mechanism_type, refunded_total_minor: @refunded_minor,
          clawed_back_minor: @clawed_back_minor, clawback_shortfall_minor: @clawback_shortfall_minor
        }
      )
      @market = m
    end

    Result.new(success?: true, refunded_total_minor: @refunded_minor,
               clawed_back_minor: @clawed_back_minor,
               clawback_shortfall_minor: @clawback_shortfall_minor, errors: [])
  end

  private

  def refund_fixed_odds!(market)
    market.bets.where(status: :open).find_each do |bet|
      credit!(bet.user, bet.stake_minor, 'fixed_odds')
      bet.update!(status: :voided)
    end
  end

  def refund_parimutuel!(market)
    LedgerEntry.where(entry_type: 'PARIMUTUEL_STAKE')
               .where("metadata->>'market_id' = ?", market.id.to_s)
               .find_each do |entry|
      credit!(entry.user, entry.amount_minor, 'parimutuel')
    end
    market.update!(parimutuel_pool_yes_minor: 0, parimutuel_pool_no_minor: 0)
  end

  def refund_lmsr!(market)
    costs = Hash.new(0)
    AuditEvent.where(action: 'lmsr_trade.place', target_type: 'Market', target_id: market.id).find_each do |ev|
      costs[ev.actor_id] += ev.metadata['cost_minor'].to_i
    end

    costs.each do |user_id, cost|
      credit!(User.find(user_id), cost, 'lmsr') if cost.positive?
    end
    LmsrPosition.for_market(market).update_all(contracts: 0)
  end

  def refund_clob!(market)
    # Cancel open/partial orders and release reservations
    market.orders.where(status: %w[open partial]).find_each do |order|
      w = order.user.wallet.lock!
      released = [order.reserved_minor, w.reserved_minor].min
      order.update!(cancelled_quantity: order.cancelled_quantity + order.unfilled_quantity, status: :cancelled)
      next if released.zero?

      w.update!(reserved_minor: w.reserved_minor - released, available_minor: w.available_minor + released)
    end

    # Net cash outlay per user: (ORDER_FILL_STAKE + ORDER_FILL_CREDIT) - CLOB_SELL_CREDIT
    net = Hash.new(0)
    LedgerEntry.where(entry_type: %w[ORDER_FILL_STAKE ORDER_FILL_CREDIT])
               .where("metadata->>'market_id' = ?", market.id.to_s)
               .find_each { |e| net[e.user_id] += e.amount_minor }
    LedgerEntry.where(entry_type: 'CLOB_SELL_CREDIT')
               .where("metadata->>'market_id' = ?", market.id.to_s)
               .find_each { |e| net[e.user_id] -= e.amount_minor }
    LedgerEntry.where(entry_type: 'CLOB_FEE')
               .where("metadata->>'market_id' = ?", market.id.to_s)
               .find_each { |e| net[e.user_id] += e.amount_minor }

    net.each do |user_id, amount|
      user = User.find(user_id)
      if amount.positive?
        credit!(user, amount, 'clob')
      elsif amount.negative?
        clawback!(user, -amount)
      end
    end
  end

  def credit!(user, amount, mechanism)
    return 0 unless amount.positive?

    wallet = user.wallet.lock!
    wallet.update!(available_minor: wallet.available_minor + amount)
    LedgerEntry.create!(user: user, actor: @actor, entry_type: 'MARKET_CANCEL_REFUND',
                        direction: 'credit', amount_minor: amount,
                        metadata: { market_id: @market.id, mechanism: mechanism })
    @refunded_minor += amount
    amount
  end

  def clawback!(user, amount)
    return 0 unless amount.positive?

    wallet = user.wallet.lock!
    taken = [amount, wallet.available_minor].min
    wallet.update!(available_minor: wallet.available_minor - taken)
    LedgerEntry.create!(user: user, actor: @actor, entry_type: 'MARKET_CANCEL_CLAWBACK',
                        direction: 'debit', amount_minor: taken,
                        metadata: { market_id: @market.id, mechanism: 'clob',
                                    requested_minor: amount, shortfall_minor: amount - taken })
    @clawed_back_minor += taken
    @clawback_shortfall_minor += (amount - taken)
    taken
  end
end
