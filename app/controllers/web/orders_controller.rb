module Web
  class OrdersController < ApplicationController
    before_action :authenticate_user!

    def create
      market = Market.find(params[:market_id])
      return render json: { error: "Not a CLOB market" }, status: :unprocessable_entity unless market.clob?

      leg    = market.market_legs.find_by!(label: params[:side])
      result = Clob::OrderMatchingService.call(
        market: market,
        incoming_order_params: {
          user: current_user,
          side: params[:side],
          price_cents: params[:price_cents].to_i,
          quantity: params[:quantity].to_i,
          market_leg: leg,
          time_in_force: (params[:time_in_force] || "GTC").downcase.to_sym
        }
      )

      if result.success?
        render json: { order_id: result.incoming_order.id, status: result.incoming_order.status }, status: :created
      else
        render json: { errors: result.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      order = Order.find(params[:id])
      return render json: { error: "Forbidden" }, status: :forbidden unless order.user_id == current_user.id
      return render json: { error: "Order cannot be cancelled" }, status: :unprocessable_entity unless order.open? || order.partial?

      released = order.reserved_minor
      ApplicationRecord.transaction do
        order.cancelled_quantity += order.unfilled_quantity
        order.status = :cancelled
        order.save!
        w = current_user.wallet
        w.update!(reserved_minor: w.reserved_minor - released, available_minor: w.available_minor + released)
      end

      render json: { order_id: order.id, status: "cancelled" }
    end
  end
end
