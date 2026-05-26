class BetslipQuoteService
  class InvalidQuote < StandardError; end
  class Conflict < StandardError; end

  TTL_SECONDS = 60

  def self.call(user:, items:, idempotency_key:)
    raise InvalidQuote, "Items cannot be empty" if items.blank?
    raise InvalidQuote, "idempotency_key is required" if idempotency_key.to_s.strip.empty?

    normalized_items = items.map do |item|
      leg_id = item[:market_leg_id] || item["market_leg_id"]
      stake = (item[:stake_minor] || item["stake_minor"]).to_i
      raise InvalidQuote, "stake_minor must be positive" unless stake.positive?

      leg = MarketLeg.find_by(id: leg_id)
      raise InvalidQuote, "Unknown market_leg #{leg_id}" unless leg
      raise InvalidQuote, "Market #{leg.market_id} is not open" unless leg.market.open?

      payout = (stake * leg.odds_minor / 10_000.0).floor
      { "market_leg_id" => leg.id, "stake_minor" => stake, "potential_payout_minor" => payout }
    end

    total_stake = normalized_items.sum { |i| i["stake_minor"] }

    existing = BetslipQuote.find_by(idempotency_key: idempotency_key)
    if existing
      raise Conflict, "idempotency_key conflict" unless payloads_match?(existing, normalized_items, total_stake)
      return existing
    end

    BetslipQuote.create!(
      user: user,
      idempotency_key: idempotency_key,
      items: normalized_items,
      total_stake_minor: total_stake,
      expires_at: Time.current + TTL_SECONDS.seconds
    )
  rescue ActiveRecord::RecordNotUnique
    # Race: another caller inserted the same key — retry once to fetch and compare.
    existing = BetslipQuote.find_by!(idempotency_key: idempotency_key)
    raise Conflict, "idempotency_key conflict" unless payloads_match?(existing, normalized_items, total_stake)
    existing
  end

  def self.payloads_match?(quote, normalized_items, total_stake)
    quote.total_stake_minor == total_stake &&
      quote.items.length == normalized_items.length &&
      quote.items.zip(normalized_items).all? do |a, b|
        a["market_leg_id"] == b["market_leg_id"] && a["stake_minor"] == b["stake_minor"]
      end
  end
  private_class_method :payloads_match?
end
