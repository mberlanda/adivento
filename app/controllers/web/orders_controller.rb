module Web
  class OrdersController < BaseController
    def create
      market = Market.find(params.expect(:market_id))

      unless market.clob?
        return respond_to do |format|
          format.html { redirect_to web_market_path(market), alert: 'Not a CLOB market' }
          format.json { render json: { error: 'Not a CLOB market' }, status: :unprocessable_content }
        end
      end

      leg    = market.market_legs.find_by!(label: params.expect(:side).upcase)
      result = Clob::OrderMatchingService.call(
        market: market,
        incoming_order_params: {
          user: current_user,
          side: params.expect(:side).upcase,
          price_cents: params[:price_cents].to_i,
          quantity: params[:quantity].to_i,
          market_leg: leg,
          time_in_force: (params[:time_in_force] || 'GTC').downcase.to_sym
        }
      )

      respond_to do |format|
        if result.success?
          format.html do
            side = params.expect(:side).upcase
            redirect_to web_market_path(market),
                        notice: "Order placed on #{side} at #{params[:price_cents].to_i}¢ for #{params[:quantity].to_i} contracts"
          end
          format.json do
            render json: { order_id: result.incoming_order.id, status: result.incoming_order.status }, status: :created
          end
        else
          format.html { redirect_to web_market_path(market), alert: result.errors.join(', ') }
          format.json { render json: { errors: result.errors }, status: :unprocessable_content }
        end
      end
    end

    def destroy
      order = Order.find(params.expect(:id))
      return render json: { error: 'Forbidden' }, status: :forbidden unless order.user_id == current_user.id

      result = Clob::OrderCancellationService.call(order: order, actor: current_user)

      unless result.success?
        return render json: { error: result.errors.join(', ') }, status: :unprocessable_content
      end

      render json: { order_id: result.order.id, status: result.order.status }
    end
  end
end
