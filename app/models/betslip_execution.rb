class BetslipExecution < ApplicationRecord
  enum :status, { completed: 0, failed: 1 }, default: :completed

  belongs_to :betslip_quote
  belongs_to :user
end
