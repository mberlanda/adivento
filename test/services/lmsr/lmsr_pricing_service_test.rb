require 'test_helper'

module Lmsr
  class LmsrPricingServiceTest < ActiveSupport::TestCase
    SUBSIDY = 100_000
    B = (SUBSIDY / (Math.log(2) * 100)).freeze

    test 'initial price at q_yes=0, q_no=0 is 50% for both outcomes' do
      svc = Lmsr::LmsrPricingService.new(lmsr_b: B, q_yes: 0, q_no: 0)

      assert_in_delta 50.0, svc.yes_probability, 0.01
      assert_in_delta 50.0, svc.no_probability,  0.01
    end

    test 'cost function C(0,0) = b * ln(2)' do
      svc = Lmsr::LmsrPricingService.new(lmsr_b: B, q_yes: 0, q_no: 0)
      expected = B * Math.log(2)

      assert_in_delta expected, svc.cost_function, 0.001
    end

    test 'trade_cost: buying 10 YES contracts from initial state is positive' do
      svc = Lmsr::LmsrPricingService.new(lmsr_b: B, q_yes: 0, q_no: 0)
      cost = svc.trade_cost(delta_yes: 10, delta_no: 0)

      assert_operator cost, :>, 0
    end

    test 'trade_cost: selling 10 YES contracts is negative (payout to trader)' do
      svc = Lmsr::LmsrPricingService.new(lmsr_b: B, q_yes: 10, q_no: 0)
      cost = svc.trade_cost(delta_yes: -10, delta_no: 0)

      assert_operator cost, :<, 0
    end

    test 'yes probability increases after buying YES contracts' do
      svc_before = Lmsr::LmsrPricingService.new(lmsr_b: B, q_yes: 0,   q_no: 0)
      svc_after  = Lmsr::LmsrPricingService.new(lmsr_b: B, q_yes: 100, q_no: 0)

      assert_operator svc_after.yes_probability, :>, svc_before.yes_probability
    end

    test 'operator max loss for binary market equals liquidity_subsidy_minor' do
      Lmsr::LmsrPricingService.new(lmsr_b: B, q_yes: 0, q_no: 0)
      max_loss = (B * Math.log(2) * 100).round

      assert_in_delta SUBSIDY, max_loss, 1
    end
  end
end
