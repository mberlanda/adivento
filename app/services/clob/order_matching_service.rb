module Clob
  class OrderMatchingService
    Result = Struct.new(:success?, :incoming_order, :fills, :errors, keyword_init: true)

    def self.call(**) = new(**).call

    def initialize(market:, incoming_order_params:)
      @market = market
      @params = incoming_order_params
    end

    def call
      ApplicationRecord.transaction do
        validate_market_trading_state!
        order = build_incoming_order
        order.save!

        if order.sell?
          validate_sell_position!(order)
        else
          reserve_funds!(order)
        end

        # FOK: check full availability before matching
        if order.fok?
          available = count_matchable_quantity(order)
          if available < order.quantity
            cancel_remainder!(order)
            emit_audit!(order, [])
            next Result.new(success?: true, incoming_order: order, fills: [], errors: [])
          end
        end

        fills = match!(order)
        apply_tif_cancellation!(order)
        emit_audit!(order, fills)
        if defined?(HotStorage::MarketSnapshotProjector)
          HotStorage::MarketSnapshotProjector.project!(market: @market, reason: 'clob.order_match')
        end
        Result.new(success?: true, incoming_order: order, fills: fills, errors: [])
      end
    rescue StandardError => e
      Result.new(success?: false, incoming_order: nil, fills: [], errors: [e.message])
    end

    private

    def validate_market_trading_state!
      raise 'Market is not open' unless @market.open?
      raise 'Market is closed for new bets' if @market.close_at.present? && @market.close_at <= Time.current
    end

    def build_incoming_order
      Order.new(
        market: @market,
        market_leg: @params[:market_leg],
        user: @params[:user],
        side: @params[:side],
        direction: @params[:direction] || 'buy',
        price_cents: @params[:price_cents],
        quantity: @params[:quantity],
        time_in_force: @params[:time_in_force] || :gtc,
        status: :open
      )
    end

    def reserve_funds!(order)
      reservation = order.price_cents * order.quantity
      wallet = order.user.wallet.lock!
      raise 'Insufficient funds' if wallet.available_minor < reservation

      wallet.update!(
        available_minor: wallet.available_minor - reservation,
        reserved_minor: wallet.reserved_minor + reservation
      )
    end

    def validate_sell_position!(order)
      net = NetPositionService.call(user: order.user, market: @market, side: order.side)
      # Contracts already committed to this user's other resting sell orders on the
      # same side must be reserved — otherwise overlapping open sells could oversell
      # the held position (TD-019).
      committed = @market.orders
                         .where(user: order.user, side: order.side, direction: 'sell', status: %w[open partial])
                         .where.not(id: order.id)
                         .sum('quantity - filled_quantity - cancelled_quantity')
      raise 'Insufficient position to sell' if (net - committed) < order.quantity
    end

    def count_matchable_quantity(incoming)
      total = 0
      resting_for(incoming).each do |resting|
        break unless compatible?(incoming, resting)

        total += resting.unfilled_quantity
        break if total >= incoming.quantity
      end
      total
    end

    def match!(incoming)
      fills = []
      resting_for(incoming).each do |resting|
        break if incoming.unfilled_quantity <= 0
        break unless compatible?(incoming, resting)

        fill_qty = [incoming.unfilled_quantity, resting.unfilled_quantity].min
        fill_price = resting.price_cents
        fills << if incoming.sell?
                   execute_sell_fill!(incoming, resting, fill_qty, fill_price)
                 else
                   execute_fill!(incoming, resting, fill_qty, fill_price)
                 end
      end
      fills
    end

    # Returns the resting orders that `incoming` can match against.
    # Sell orders match against same-side buy resting orders.
    # Buy orders match against sell resting orders first, then cross-side buy orders.
    def resting_for(incoming)
      if incoming.sell?
        @market.orders
               .where(side: incoming.side, direction: 'buy', status: %w[open partial])
               .lock('FOR UPDATE SKIP LOCKED')
               .order(price_cents: :desc, created_at: :asc)
      else
        # Buy order: first try resting sell orders on same side (cheaper), then cross-side
        sell_resting = @market.orders
                              .where(side: incoming.side, direction: 'sell', status: %w[open partial])
                              .lock('FOR UPDATE SKIP LOCKED')
                              .order(price_cents: :asc, created_at: :asc)
        cross_resting = @market.orders
                               .where(side: opposite(incoming.side), direction: 'buy', status: %w[open partial])
                               .lock('FOR UPDATE SKIP LOCKED')
                               .order(price_cents: :desc, created_at: :asc)
        # Array#+ materialises both relations into memory. Acceptable at current book sizes;
        # replace with a UNION query or lazy iteration if order books grow large.
        sell_resting + cross_resting
      end
    end

    def compatible?(incoming, resting)
      if incoming.sell?
        # Sell YES at ask, resting buy YES at bid — compatible if bid >= ask
        resting.price_cents >= incoming.price_cents
      elsif resting.sell?
        # Buy YES at bid, resting sell YES at ask — compatible if bid >= ask
        incoming.price_cents >= resting.price_cents
      else
        # Both are buy orders on opposite sides — original cross-side compatibility
        if incoming.side == 'YES'
          incoming.price_cents + resting.price_cents >= 100
        else
          resting.price_cents + incoming.price_cents >= 100
        end
      end
    end

    # Original fill: both sides are buy orders, together they fund a new contract.
    def execute_fill!(taker, maker, qty, price)
      taker_stake = taker.price_cents * qty
      maker_stake = maker.price_cents * qty

      taker.filled_quantity += qty
      taker.status = taker.unfilled_quantity.zero? ? :filled : :partial
      taker.save!

      maker.filled_quantity += qty
      maker.status = maker.unfilled_quantity.zero? ? :filled : :partial
      maker.save!

      maker_wallet = maker.user.wallet.lock!
      maker_wallet.update!(reserved_minor: maker_wallet.reserved_minor - maker_stake)

      taker_wallet = taker.user.wallet.lock!
      taker_wallet.update!(reserved_minor: taker_wallet.reserved_minor - taker_stake)

      fill_meta = { market_id: @market.id, fill_price: price, fill_qty: qty }
      LedgerEntry.create!(
        user: taker.user, actor: taker.user,
        entry_type: 'ORDER_FILL_STAKE', direction: 'debit',
        amount_minor: taker_stake, metadata: fill_meta
      )
      LedgerEntry.create!(
        user: maker.user, actor: taker.user,
        entry_type: 'ORDER_FILL_CREDIT', direction: 'credit',
        amount_minor: maker_stake, metadata: fill_meta
      )

      @market.update_columns(last_fill_price_cents: price, updated_at: Time.current)

      fee = (@market.taker_fee_bps.to_i * taker_stake / 10_000.0).ceil
      if fee.positive?
        LedgerEntry.create!(
          user: taker.user, actor: taker.user,
          entry_type: 'CLOB_FEE', direction: 'debit',
          amount_minor: fee, metadata: fill_meta
        )
        taker_wallet.update!(available_minor: taker_wallet.available_minor - fee)
      end

      { taker_order: taker, maker_order: maker, qty: qty, price: price, fee: fee }
    end

    # Sell fill: seller gives up existing contracts, buyer pays cash.
    # Fill price = maker's (buyer's) price_cents when seller is taker,
    # or seller's (sell order's) price_cents when seller is maker.
    # No taker fee here: the seller is exiting an existing position (providing liquidity),
    # not creating new contracts the way a cross-side buy match does.
    def execute_sell_fill!(sell_order, buy_order, qty, fill_price)
      proceeds = fill_price * qty # what the seller receives
      buyer_stake = fill_price * qty

      sell_order.filled_quantity += qty
      sell_order.status = sell_order.unfilled_quantity.zero? ? :filled : :partial
      sell_order.save!

      buy_order.filled_quantity += qty
      buy_order.status = buy_order.unfilled_quantity.zero? ? :filled : :partial
      buy_order.save!

      # Release buyer's reservation for this fill quantity
      buyer_wallet = buy_order.user.wallet.lock!
      buyer_wallet.update!(reserved_minor: buyer_wallet.reserved_minor - buyer_stake)

      # Credit seller for the proceeds (no prior reservation to release)
      seller_wallet = sell_order.user.wallet.lock!
      seller_wallet.update!(available_minor: seller_wallet.available_minor + proceeds)

      fill_meta = { market_id: @market.id, fill_price: fill_price, fill_qty: qty }
      LedgerEntry.create!(
        user: sell_order.user, actor: sell_order.user,
        entry_type: 'CLOB_SELL_CREDIT', direction: 'credit',
        amount_minor: proceeds, metadata: fill_meta
      )
      LedgerEntry.create!(
        user: buy_order.user, actor: sell_order.user,
        entry_type: 'ORDER_FILL_STAKE', direction: 'debit',
        amount_minor: buyer_stake, metadata: fill_meta
      )

      @market.update_columns(last_fill_price_cents: fill_price, updated_at: Time.current)

      { taker_order: sell_order, maker_order: buy_order, qty: qty, price: fill_price, fee: 0 }
    end

    def apply_tif_cancellation!(order)
      return if order.filled? || order.cancelled?
      return unless order.ioc?

      cancel_remainder!(order)
    end

    def cancel_remainder!(order)
      unfilled = order.unfilled_quantity
      return if unfilled <= 0

      order.cancelled_quantity += unfilled
      order.status = order.filled_quantity.zero? ? :cancelled : :filled
      order.save!

      return unless order.buy?

      release = order.price_cents * unfilled
      wallet = order.user.wallet.lock!
      wallet.update!(
        reserved_minor: wallet.reserved_minor - release,
        available_minor: wallet.available_minor + release
      )
    end

    def emit_audit!(order, fills)
      AuditEvent.create!(
        action: 'order.place',
        actor: order.user,
        target_type: 'Order', target_id: order.id,
        metadata: { side: order.side, direction: order.direction, price_cents: order.price_cents,
                    quantity: order.quantity, fills: fills.size }
      )
      fills.each do |f|
        AuditEvent.create!(
          action: 'order.fill',
          actor: f[:taker_order].user,
          target_type: 'Order', target_id: f[:taker_order].id,
          metadata: { fill_qty: f[:qty], fill_price: f[:price], counterparty_order_id: f[:maker_order].id }
        )
      end
    end

    def opposite(side) = side == 'YES' ? 'NO' : 'YES'
  end
end
