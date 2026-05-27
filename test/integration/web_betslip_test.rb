require 'test_helper'

class WebBetslipTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:player)
    @user.wallet.update!(available_minor: 100_000)
    @market = markets(:open_market)
    @yes_leg = market_legs(:yes_leg)
    @no_leg = market_legs(:no_leg)
    @market.bets.delete_all

    post '/signin', params: { email: @user.email, password: 'password123' }
  end

  test 'quote then execute happy path' do
    post '/web/betslips/quotes', params: {
      items: [
        { market_leg_id: @yes_leg.id, stake_minor: 500 },
        { market_leg_id: @no_leg.id, stake_minor: 1000 }
      ],
      idempotency_key: 'happy-1'
    }, as: :json

    assert_response :success
    quote_id = response.parsed_body['quote_id']

    assert_equal 1500, response.parsed_body['total_stake_minor']

    post '/web/betslips/execute', params: { quote_id: quote_id }, as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal 'completed', body['status']
    assert_equal 2, body['bet_ids'].length

    get "/web/betslips/executions/#{body['execution_id']}"

    assert_response :success
    assert_equal body['bet_ids'], response.parsed_body['bet_ids']
  end

  test 'idempotency replay returns same quote' do
    payload = {
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: 'replay-int'
    }
    post '/web/betslips/quotes', params: payload, as: :json
    id1 = response.parsed_body['quote_id']

    post '/web/betslips/quotes', params: payload, as: :json

    assert_response :success
    assert_equal id1, response.parsed_body['quote_id']
  end

  test 'idempotency conflict returns 409' do
    post '/web/betslips/quotes', params: {
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: 'conflict-int'
    }, as: :json

    assert_response :success

    post '/web/betslips/quotes', params: {
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 999 }],
      idempotency_key: 'conflict-int'
    }, as: :json

    assert_response :conflict
  end

  test 'expired quote returns 422 on execute' do
    post '/web/betslips/quotes', params: {
      items: [{ market_leg_id: @yes_leg.id, stake_minor: 500 }],
      idempotency_key: 'expired-int'
    }, as: :json
    quote_id = response.parsed_body['quote_id']
    BetslipQuote.find(quote_id).update_column(:expires_at, 1.second.ago)

    initial_balance = @user.wallet.reload.available_minor
    post '/web/betslips/execute', params: { quote_id: quote_id }, as: :json

    assert_response :unprocessable_entity
    assert_equal initial_balance, @user.wallet.reload.available_minor
  end

  test "positions index returns only current user's open bets" do
    bet = Bet.create!(
      user: @user, market: @market, market_leg: @yes_leg,
      stake_minor: 1000, fee_minor: 10, net_stake_minor: 990,
      odds_minor: @yes_leg.odds_minor, potential_payout_minor: 500, status: :open
    )

    get '/web/positions'

    assert_response :success
    ids = response.parsed_body['positions'].pluck('bet_id')

    assert_includes ids, bet.id
  end

  test 'cashout quote then execute credits wallet and voids bet' do
    @market.update!(fee_bps: 100)
    @yes_leg.update!(odds_minor: 4000)
    # Stake 5000 * odds 4000 / 10_000 = 2000 gross payout
    bet = Bet.create!(
      user: @user, market: @market, market_leg: @yes_leg,
      stake_minor: 5000, fee_minor: 50, net_stake_minor: 4950,
      odds_minor: @yes_leg.odds_minor, potential_payout_minor: 2000, status: :open
    )

    post '/web/positions/cashout_quotes', params: { bet_id: bet.id }, as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal 2000, body['gross_payout_minor']
    assert_equal 20, body['fee_minor']
    assert_equal 1980, body['net_payout_minor']

    initial_balance = @user.wallet.reload.available_minor
    post '/web/positions/cashout_execute', params: { bet_id: bet.id }, as: :json

    assert_response :success
    assert_equal 'completed', response.parsed_body['status']
    assert_equal 1980, response.parsed_body['credited_minor']
    assert_equal initial_balance + 1980, @user.wallet.reload.available_minor
    assert_predicate bet.reload, :voided?
  end

  test 'cashout on non-open bet returns 422' do
    bet = Bet.create!(
      user: @user, market: @market, market_leg: @yes_leg,
      stake_minor: 1000, fee_minor: 10, net_stake_minor: 990,
      odds_minor: @yes_leg.odds_minor, potential_payout_minor: 500, status: :voided
    )
    post '/web/positions/cashout_execute', params: { bet_id: bet.id }, as: :json

    assert_response :unprocessable_entity
  end

  test "execution show 404 for another user's execution" do
    quote = BetslipQuote.create!(
      user: users(:moderator),
      idempotency_key: 'other-user',
      items: [],
      total_stake_minor: 0,
      expires_at: 60.seconds.from_now
    )
    execution = BetslipExecution.create!(
      betslip_quote: quote, user: users(:moderator), bet_ids: [], status: :completed
    )
    get "/web/betslips/executions/#{execution.id}"

    assert_response :not_found
  end
end
