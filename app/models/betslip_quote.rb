class BetslipQuote < ApplicationRecord
  enum :status, { pending: 0, executed: 1, expired: 2 }, default: :pending

  belongs_to :user
  has_one :betslip_execution, dependent: :restrict_with_exception

  validates :idempotency_key, presence: true, uniqueness: true
  validates :total_stake_minor, numericality: { greater_than_or_equal_to: 0 }
  validates :expires_at, presence: true

  def expired?
    expires_at < Time.current
  end
end
