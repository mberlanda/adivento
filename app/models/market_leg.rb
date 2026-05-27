class MarketLeg < ApplicationRecord
  belongs_to :market
  has_many :bets, dependent: :restrict_with_exception

  validates :label, presence: true, uniqueness: { scope: :market_id }
  validates :odds_minor, numericality: { greater_than: 0, less_than_or_equal_to: 10_000 }

  validate :market_leg_count_within_limit, on: :create

  private

  def market_leg_count_within_limit
    return unless market

    return unless market.market_legs.count >= 2

    errors.add(:base, 'Market already has the maximum of 2 legs')
  end
end
