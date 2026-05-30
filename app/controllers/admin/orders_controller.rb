module Admin
  class OrdersController < BaseController
    before_action -> { require_permission!('market.update') }

    def create
      market = Market.find(params.expect(:market_id))
      return render json: { error: 'Not a CLOB market' }, status: :unprocessable_content unless market.clob?

      user = User.find(params.expect(:user_id))
      leg  = market.market_legs.find_by!(label: params.expect(:side))
      result = Clob::OrderMatchingService.call(
        market: market,
        incoming_order_params: {
          user: user,
          side: params[:side],
          price_cents: params[:price_cents].to_i,
          quantity: params[:quantity].to_i,
          market_leg: leg,
          time_in_force: (params[:time_in_force] || 'GTC').downcase.to_sym
        }
      )

      if result.success?
        render json: order_json(result.incoming_order), status: :created
      else
        render json: { errors: result.errors }, status: :unprocessable_content
      end
    end

    def destroy
      order = Order.find(params.expect(:id))
      result = Clob::OrderCancellationService.call(order: order, actor: current_user)

      unless result.success?
        return render json: { error: result.errors.join(', ') }, status: :unprocessable_content
      end

      render json: {
        order_id: result.order.id,
        status: result.order.status,
        released_minor: result.released_minor
      }
    end

    private

    def order_json(ord)
      {
        order_id: ord.id, market_id: ord.market_id, side: ord.side,
        price_cents: ord.price_cents, quantity: ord.quantity,
        filled_quantity: ord.filled_quantity, status: ord.status,
        time_in_force: ord.time_in_force, reserved_minor: ord.reserved_minor
      }
    end
  end
end
