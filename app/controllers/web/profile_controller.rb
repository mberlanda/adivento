module Web
  class ProfileController < BaseController
    def show
      @wallet = current_user.wallet
      status_filter = params[:status].presence

      @bets = Bet.includes(:market, :market_leg)
                 .where(user_id: current_user.id)
                 .order(created_at: :desc)

      @bets = @bets.where(status: status_filter) if status_filter && Bet.statuses.key?(status_filter)

      settled = Bet.where(user_id: current_user.id, status: %i[settled_win settled_loss])
      won     = Bet.where(user_id: current_user.id, status: :settled_win)
      lost    = Bet.where(user_id: current_user.id, status: :settled_loss)

      @pnl = {
        total_staked: settled.sum(:net_stake_minor),
        total_returned: won.sum(:potential_payout_minor),
        open_count: Bet.where(user_id: current_user.id, status: :open).count,
        won_count: won.count,
        lost_count: lost.count
      }
      @pnl[:net_pnl] = @pnl[:total_returned] - @pnl[:total_staked]
      total_decisive = @pnl[:won_count] + @pnl[:lost_count]
      @pnl[:win_rate] = total_decisive.positive? ? (@pnl[:won_count].to_f / total_decisive * 100).round(1) : nil
    end
  end
end
