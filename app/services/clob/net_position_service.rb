module Clob
  # Returns the net number of contracts a user holds for a given side on a CLOB market.
  # net = filled buy orders - filled sell orders on that side.
  module NetPositionService
    def self.call(user:, market:, side:)
      bought = market.orders.where(user: user, side: side, direction: 'buy').sum(:filled_quantity)
      sold   = market.orders.where(user: user, side: side, direction: 'sell').sum(:filled_quantity)
      bought - sold
    end
  end
end
