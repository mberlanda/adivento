module Lmsr
  class LmsrPricingService
    def initialize(b:, q_yes:, q_no:)
      @b     = b.to_f
      @q_yes = q_yes.to_f
      @q_no  = q_no.to_f
    end

    # C(q) = b * ln(sum(exp(q_i / b)))
    def cost_function(q_yes: @q_yes, q_no: @q_no)
      @b * Math.log(Math.exp(q_yes / @b) + Math.exp(q_no / @b))
    end

    def trade_cost(delta_yes: 0, delta_no: 0)
      cost_function(q_yes: @q_yes + delta_yes, q_no: @q_no + delta_no) - cost_function
    end

    def yes_probability
      exp_yes = Math.exp(@q_yes / @b)
      exp_no  = Math.exp(@q_no  / @b)
      (exp_yes / (exp_yes + exp_no) * 100).round(4)
    end

    def no_probability = (100 - yes_probability).round(4)

    # b = subsidy / (ln(2) * 100) ensures operator worst-case loss = subsidy
    def self.b_from_subsidy(liquidity_subsidy_minor)
      liquidity_subsidy_minor.to_f / (Math.log(2) * 100)
    end
  end
end
