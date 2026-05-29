class Order < ApplicationRecord
  belongs_to :market
  belongs_to :market_leg
  belongs_to :user

  enum :status, { open: 0, partial: 1, filled: 2, cancelled: 3 }
  enum :time_in_force, { gtc: 0, ioc: 1, fok: 2 }

  validates :side,      inclusion: { in: %w[YES NO] }
  validates :direction, inclusion: { in: %w[buy sell] }
  validates :price_cents, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 99, only_integer: true }
  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :filled_quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :cancelled_quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :filled_plus_cancelled_lte_quantity

  def buy?  = direction == 'buy'
  def sell? = direction == 'sell'

  def unfilled_quantity = quantity - filled_quantity - cancelled_quantity
  def reserved_minor    = buy? ? price_cents * unfilled_quantity : 0

  private

  def filled_plus_cancelled_lte_quantity
    return unless filled_quantity && cancelled_quantity && quantity

    return unless filled_quantity + cancelled_quantity > quantity

    errors.add(:base, 'filled_quantity + cancelled_quantity cannot exceed quantity')
  end
end
