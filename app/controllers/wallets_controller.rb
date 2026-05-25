class WalletsController < ApplicationController
  include Authentication

  def show
    wallet = current_user.wallet
    render json: {
      user_id: current_user.id,
      asset_code: wallet.asset_code,
      available_minor: wallet.available_minor,
      reserved_minor: wallet.reserved_minor,
      total_minor: wallet.total_minor
    }
  end
end
