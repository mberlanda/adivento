module Web
  class OrdersController < BaseController
    def create
      market = Market.find(params.expect(:market_id))
      return render json: { error: 'Not a CLOB market' }, status: :unprocessable_content unless market.clob?
      return render json: { error: 'Market is not open' }, status: :unprocessable_content unless market.open?

      leg    = market.market_legs.find_by!(label: params.expect(:side))
      result = Clob::OrderMatchingService.call(
        market: market,
        incoming_order_params: {
          user: current_user,
          side: params[:side],
          price_cents: params[:price_cents].to_i,
          quantity: params[:quantity].to_i,
          market_leg: leg,
          time_in_force: (params[:time_in_force] || 'GTC').downcase.to_sym
        }
      )

      if result.success?
        render json: { order_id: result.incoming_order.id, status: result.incoming_order.status }, status: :created
      else
        render json: { errors: result.errors }, status: :unprocessable_content
      end
    end

    def destroy
      order = Order.lock.find(params.expect(:id))
      return render json: { error: 'Forbidden' }, status: :forbidden unless order.user_id == current_user.id
      unless order.open? || order.partial?
        return render json: { error: 'Order cannot be cancelled' },
                      status: :unprocessable_content
      end

      released = order.reserved_minor
      ApplicationRecord.transaction do
        order.cancelled_quantity += order.unfilled_quantity
        order.status = :cancelled
        order.save!
        wallet = current_user.wallet.lock!
        wallet.update!(reserved_minor: wallet.reserved_minor - released, available_minor: wallet.available_minor + released)
      end

      render json: { order_id: order.id, status: 'cancelled' }
    end
  end
end
