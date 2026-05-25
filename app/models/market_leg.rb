class MarketLeg < ApplicationRecord
  belongs_to :market

  validates :label, presence: true, uniqueness: { scope: :market_id }
  validates :odds_minor, numericality: { greater_than: 0, less_than_or_equal_to: 10_000 }
end
