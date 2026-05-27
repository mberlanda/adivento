class Market < ApplicationRecord
  MECHANISM_TYPES = %w[fixed_odds clob lmsr parimutuel].freeze

  enum :status, { draft: 0, open: 1, settled: 2, cancelled: 3 }, default: :draft

  belongs_to :created_by, class_name: 'User', inverse_of: :created_markets
  belongs_to :settled_by, class_name: 'User', optional: true, inverse_of: :settled_markets
  has_many :market_legs, dependent: :destroy
  has_many :bets, dependent: :destroy
  has_many :orders, dependent: :destroy

  validates :question, presence: true
  validates :description, presence: true
  validates :mechanism_type, inclusion: { in: MECHANISM_TYPES }
  validates :fee_bps, numericality: { greater_than_or_equal_to: 0 }
  validates :liability_cap_minor, numericality: { greater_than: 0 }

  validate :requires_two_legs_to_open, if: -> { will_save_change_to_status? && open? }
  validate :mechanism_type_immutable_when_open
  validate :mechanism_fee_config_present

  before_save :compute_lmsr_b_parameter, if: -> { lmsr? && will_save_change_to_status? && open? }

  def fixed_odds? = mechanism_type == 'fixed_odds'
  def clob?       = mechanism_type == 'clob'
  def lmsr?       = mechanism_type == 'lmsr'
  def parimutuel? = mechanism_type == 'parimutuel'

  def pricing_engine
    case mechanism_type
    when 'fixed_odds' then FixedOddsPricingEngine.new(self)
    when 'clob'       then ClobPricingEngine.new(self)
    when 'lmsr'       then LmsrPricingEngine.new(self)
    when 'parimutuel' then ParimutuelPricingEngine.new(self)
    end
  end

  class FixedOddsPricingEngine
    def initialize(market) = @market = market
    def current_price_for(leg) = leg.odds_minor
  end

  class ClobPricingEngine
    def initialize(market) = @market = market

    def order_book_summary
      bids = @market.orders.where(side: 'YES', status: %w[open partial]).order(price_cents: :desc)
      asks = @market.orders.where(side: 'NO',  status: %w[open partial]).order(price_cents: :asc)
      { bid: bids.first&.price_cents, ask: asks.first&.price_cents }
    end
  end

  class LmsrPricingEngine
    def initialize(market) = @market = market

    def yes_probability
      b = @market.lmsr_b_parameter.to_f
      return 50.0 if b.zero?

      q_yes = @market.lmsr_q_yes.to_f
      q_no  = @market.lmsr_q_no.to_f
      exp_yes = Math.exp(q_yes / b)
      exp_no  = Math.exp(q_no  / b)
      (exp_yes / (exp_yes + exp_no) * 100).round(2)
    end

    def no_probability = (100 - yes_probability).round(2)
  end

  class ParimutuelPricingEngine
    def initialize(market) = @market = market

    def yes_probability
      total = @market.parimutuel_pool_yes_minor + @market.parimutuel_pool_no_minor
      return 50.0 if total.zero?

      (@market.parimutuel_pool_yes_minor.to_f / total * 100).round(2)
    end

    def no_probability = (100 - yes_probability).round(2)
  end

  private

  def requires_two_legs_to_open
    return if market_legs.size == 2

    errors.add(:base, 'Market must have exactly 2 legs to open')
  end

  def mechanism_type_immutable_when_open
    return unless persisted? && will_save_change_to_mechanism_type?
    return if mechanism_type_was.nil? || status_in_database == Market.statuses[:draft]

    errors.add(:mechanism_type, 'cannot be changed after market is open')
  end

  def mechanism_fee_config_present
    case mechanism_type
    when 'clob'
      errors.add(:taker_fee_bps, 'must be present for CLOB markets') if taker_fee_bps.nil?
      errors.add(:taker_fee_bps, 'must be between 0 and 200') unless taker_fee_bps.nil? || taker_fee_bps.between?(0, 200)
    when 'lmsr'
      errors.add(:liquidity_subsidy_minor, 'must be positive for LMSR markets') unless liquidity_subsidy_minor.to_i.positive?
      errors.add(:spread_fee_bps, 'must be between 0 and 500') unless spread_fee_bps.nil? || spread_fee_bps.between?(0, 500)
    when 'parimutuel'
      errors.add(:takeout_bps, 'must be between 1000 and 3000') unless takeout_bps.to_i.between?(1000, 3000)
    end
  end

  def compute_lmsr_b_parameter
    return if liquidity_subsidy_minor.nil? || liquidity_subsidy_minor <= 0

    self.lmsr_b_parameter = liquidity_subsidy_minor.to_f / (Math.log(2) * 100)
  end
end
