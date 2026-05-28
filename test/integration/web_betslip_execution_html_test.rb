require 'test_helper'

class WebBetslipExecutionHtmlTest < ActionDispatch::IntegrationTest
  setup do
    @player = users(:player)
    @quote = BetslipQuote.create!(
      user: @player,
      idempotency_key: "exec-html-#{SecureRandom.hex(4)}",
      items: [],
      total_stake_minor: 500,
      expires_at: 60.seconds.from_now
    )
    @execution = BetslipExecution.create!(
      betslip_quote: @quote, user: @player, bet_ids: [], status: :completed
    )
  end

  test 'execution confirmation page renders HTML' do
    get "/web/betslips/executions/#{@execution.id}",
        headers: auth_headers_for(@player)
    assert_response :success
    assert_select '[data-testid="execution-confirmation"]'
  end

  test 'execution confirmation page still returns JSON when requested' do
    get "/web/betslips/executions/#{@execution.id}",
        headers: auth_headers_for(@player).merge('Accept' => 'application/json')
    assert_response :success
    body = response.parsed_body
    assert_equal @execution.id, body['execution_id']
    assert_equal 'completed', body['status']
  end

  test 'execution 404 redirects to markets page in HTML' do
    get '/web/betslips/executions/999999',
        headers: auth_headers_for(@player)
    assert_redirected_to web_markets_path
  end
end
