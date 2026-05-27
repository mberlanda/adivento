class PriceSnapshot < ApplicationRecord
  belongs_to :market

  validates :mechanism_type, presence: true
  validates :snapshot_data, presence: true
  validates :recorded_at, presence: true
end
