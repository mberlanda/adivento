module Admin
  class OrdersController < BaseController
    before_action -> { require_permission!('market.update') }

    def create
      market = Market.find(params[:market_id])
      return render json: { error: "Not a CLOB market" }, status: :unprocessable_entity unless market.clob?

      user = User.find(params[:user_id])
      leg  = market.market_legs.find_by!(label: params[:side])
      result = Clob::OrderMatchingService.call(
        market: market,
        incoming_order_params: {
          user: user,
          side: params[:side],
          price_cents: params[:price_cents].to_i,
          quantity: params[:quantity].to_i,
          market_leg: leg,
          time_in_force: (params[:time_in_force] || "GTC").downcase.to_sym
        }
      )

      if result.success?
        render json: order_json(result.incoming_order), status: :created
      else
        render json: { errors: result.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      order = Order.find(params[:id])
      return render json: { error: "Order cannot be cancelled" }, status: :unprocessable_entity unless order.open? || order.partial?

      released = order.reserved_minor
      ApplicationRecord.transaction do
        order.cancelled_quantity += order.unfilled_quantity
        order.status = :cancelled
        order.save!
        w = order.user.wallet
        w.update!(reserved_minor: w.reserved_minor - released, available_minor: w.available_minor + released)
        AuditEvent.create!(
          action: "order.cancel",
          actor: current_user,
          target_type: "Order", target_id: order.id,
          metadata: { released_minor: released }
        )
      end

      render json: { order_id: order.id, status: "cancelled", released_minor: released }
    end

    private

    def order_json(o)
      {
        order_id: o.id, market_id: o.market_id, side: o.side,
        price_cents: o.price_cents, quantity: o.quantity,
        filled_quantity: o.filled_quantity, status: o.status,
        time_in_force: o.time_in_force, reserved_minor: o.reserved_minor
      }
    end
  end
end
