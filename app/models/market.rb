class Market < ApplicationRecord
  enum :status, { draft: 0, open: 1, settled: 2, cancelled: 3 }, default: :draft

  belongs_to :created_by, class_name: "User", inverse_of: :created_markets
  belongs_to :settled_by, class_name: "User", optional: true, inverse_of: :settled_markets
  has_many :market_legs, dependent: :destroy

  validates :question, presence: true
  validates :description, presence: true
end
