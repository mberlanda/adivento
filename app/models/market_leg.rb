class MarketLeg < ApplicationRecord
  belongs_to :market
  has_many :bets, dependent: :restrict_with_exception

  validates :label, presence: true, uniqueness: { scope: :market_id }
  validates :odds_minor, numericality: { greater_than: 0, less_than_or_equal_to: 10_000 }
end
