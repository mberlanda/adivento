class Bet < ApplicationRecord
  enum :status, { open: 0, settled_win: 1, settled_loss: 2, voided: 3 }, default: :open

  belongs_to :user
  belongs_to :market
  belongs_to :market_leg

  validates :stake_minor, :fee_minor, :net_stake_minor, :potential_payout_minor, numericality: { greater_than_or_equal_to: 0 }
  validates :odds_minor, numericality: { greater_than: 0 }
end
