class LedgerEntry < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: "User"

  validates :entry_type, presence: true
  validates :direction, inclusion: { in: %w[credit debit] }
  validates :amount_minor, numericality: { greater_than: 0 }
end
