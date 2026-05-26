require "test_helper"

class BetslipQuoteTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
  end

  test "valid quote can be created" do
    quote = BetslipQuote.create!(
      user: @user,
      idempotency_key: "key-1",
      items: [{ "market_leg_id" => 1, "stake_minor" => 500, "potential_payout_minor" => 1000 }],
      total_stake_minor: 500,
      expires_at: 60.seconds.from_now
    )
    assert quote.persisted?
    assert_predicate quote, :pending?
  end

  test "idempotency_key is unique" do
    BetslipQuote.create!(
      user: @user,
      idempotency_key: "dup-key",
      items: [],
      total_stake_minor: 0,
      expires_at: 60.seconds.from_now
    )
    duplicate = BetslipQuote.new(
      user: @user,
      idempotency_key: "dup-key",
      items: [],
      total_stake_minor: 0,
      expires_at: 60.seconds.from_now
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:idempotency_key], "has already been taken"
  end

  test "expired? returns true when expires_at is in the past" do
    quote = BetslipQuote.new(expires_at: 1.second.ago)
    assert quote.expired?
  end

  test "expired? returns false when expires_at is in the future" do
    quote = BetslipQuote.new(expires_at: 60.seconds.from_now)
    assert_not quote.expired?
  end
end
