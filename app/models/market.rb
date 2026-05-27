class Market < ApplicationRecord
  enum :status, { draft: 0, open: 1, settled: 2, cancelled: 3 }, default: :draft

  belongs_to :created_by, class_name: 'User', inverse_of: :created_markets
  belongs_to :settled_by, class_name: 'User', optional: true, inverse_of: :settled_markets
  has_many :market_legs, dependent: :destroy
  has_many :bets, dependent: :destroy

  validates :question, presence: true
  validates :description, presence: true
  validates :mechanism_type, presence: true
  validates :fee_bps, numericality: { greater_than_or_equal_to: 0 }
  validates :liability_cap_minor, numericality: { greater_than: 0 }

  validate :requires_two_legs_to_open, if: -> { will_save_change_to_status? && open? }

  private

  def requires_two_legs_to_open
    return if market_legs.size == 2

    errors.add(:base, 'Market must have exactly 2 legs to open')
  end
end
