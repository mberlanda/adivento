class Wallet < ApplicationRecord
  belongs_to :user

  validates :asset_code, presence: true
  validates :available_minor, numericality: { greater_than_or_equal_to: 0 }
  validates :reserved_minor, numericality: { greater_than_or_equal_to: 0 }

  def total_minor
    available_minor + reserved_minor
  end
end
