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
        order = build_incoming_order
        order.save!
        reserve_funds!(order)

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

    def build_incoming_order
      Order.new(
        market: @market,
        market_leg: @params[:market_leg],
        user: @params[:user],
        side: @params[:side],
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

    def count_matchable_quantity(incoming)
      opposite_side  = incoming.side == 'YES' ? 'NO' : 'YES'
      resting_orders = @market.orders
                              .where(side: opposite_side, status: %w[open partial])
                              .order(price_cents: :desc, created_at: :asc)

      total = 0
      resting_orders.each do |resting|
        break unless compatible?(incoming, resting)

        total += resting.unfilled_quantity
        break if total >= incoming.quantity
      end
      total
    end

    def match!(incoming)
      fills = []
      opposite_side  = incoming.side == 'YES' ? 'NO' : 'YES'
      resting_orders = @market.orders
                              .where(side: opposite_side, status: %w[open partial])
                              .lock('FOR UPDATE SKIP LOCKED')
                              .order(price_cents: :desc, created_at: :asc)

      resting_orders.each do |resting|
        break if incoming.unfilled_quantity <= 0
        break unless compatible?(incoming, resting)

        fill_qty   = [incoming.unfilled_quantity, resting.unfilled_quantity].min
        fill_price = resting.price_cents
        fills << execute_fill!(incoming, resting, fill_qty, fill_price)
      end
      fills
    end

    def compatible?(incoming, resting)
      if incoming.side == 'YES'
        incoming.price_cents + resting.price_cents >= 100
      else
        resting.price_cents + incoming.price_cents >= 100
      end
    end

    def execute_fill!(taker, maker, qty, price)
      # Each side pays their own price; together they sum to 100 (contract value)
      taker_stake = taker.price_cents * qty
      maker_stake = maker.price_cents * qty

      taker.filled_quantity += qty
      taker.status = taker.unfilled_quantity.zero? ? :filled : :partial
      taker.save!

      maker.filled_quantity += qty
      maker.status = maker.unfilled_quantity.zero? ? :filled : :partial
      maker.save!

      # Release reservation for the filled quantity (stake is now committed)
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

      # Taker fee charged on taker's stake
      fee = (@market.taker_fee_bps.to_i * taker_stake / 10_000.0).ceil
      if fee.positive?
        LedgerEntry.create!(
          user: taker.user, actor: taker.user,
          entry_type: 'CLOB_FEE', direction: 'debit',
          amount_minor: fee
        )
        taker_wallet.update!(available_minor: taker_wallet.available_minor - fee)
      end

      { taker_order: taker, maker_order: maker, qty: qty, price: price, fee: fee }
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
        metadata: { side: order.side, price_cents: order.price_cents, quantity: order.quantity, fills: fills.size }
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
  end
end
