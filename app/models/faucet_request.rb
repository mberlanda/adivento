class FaucetRequest < ApplicationRecord
  enum :status, { pending: 0, approved: 1, rejected: 2 }, default: :pending

  belongs_to :user
  belongs_to :reviewed_by, class_name: 'User', optional: true

  validates :amount_minor, numericality: { greater_than: 0 }
end
