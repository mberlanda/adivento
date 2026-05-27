module Web
  class LeaderboardController < BaseController
    skip_before_action :authenticate_request!
    before_action :attach_current_user

    def index
      @entries = leaderboard_entries
    end

    private

    def attach_current_user
      @current_user = find_authenticated_user
    rescue JWT::DecodeError, JWT::ExpiredSignature
      @current_user = nil
    end

    def leaderboard_entries
      Bet
        .where(status: %i[settled_win settled_loss])
        .joins(:user)
        .group('users.id', 'users.email')
        .select(
          'users.id AS user_id',
          'users.email AS email',
          'COUNT(*) AS total_bets',
          "SUM(CASE WHEN bets.status = #{Bet.statuses[:settled_win]} THEN 1 ELSE 0 END) AS won_bets",
          "SUM(CASE WHEN bets.status = #{Bet.statuses[:settled_loss]} THEN 1 ELSE 0 END) AS lost_bets",
          'SUM(bets.net_stake_minor) AS total_staked',
          "SUM(CASE WHEN bets.status = #{Bet.statuses[:settled_win]} " \
          'THEN bets.potential_payout_minor ELSE 0 END) AS total_returned'
        )
        .order(Arel.sql('total_returned - total_staked DESC'))
        .limit(50)
    end
  end
end
