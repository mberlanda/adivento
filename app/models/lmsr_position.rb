class LmsrPosition < ApplicationRecord
  belongs_to :user
  belongs_to :market

  validates :side, inclusion: { in: %w[YES NO] }
  validates :contracts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: { scope: %i[market_id side] }

  scope :for_market, ->(market) { where(market: market) }
  scope :holding, -> { where('contracts > 0') }
end
