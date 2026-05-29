module Web
  class LeaderboardController < BaseController
    skip_before_action :authenticate_request!
    before_action :attach_current_user

    STAKE_TYPES  = %w[BET_STAKE LMSR_TRADE_STAKE PARIMUTUEL_STAKE ORDER_FILL_STAKE].freeze
    RETURN_TYPES = %w[BET_WIN_PAYOUT BET_CASHOUT_PAYOUT SETTLEMENT_WIN ORDER_FILL_CREDIT].freeze

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
      stake_sql  = STAKE_TYPES.map  { |t| "'#{t}'" }.join(',')
      return_sql = RETURN_TYPES.map { |t| "'#{t}'" }.join(',')

      staked_expr   = "SUM(CASE WHEN ledger_entries.entry_type IN (#{stake_sql}) " \
                      'THEN ledger_entries.amount_minor ELSE 0 END)'
      returned_expr = "SUM(CASE WHEN ledger_entries.entry_type IN (#{return_sql}) " \
                      'THEN ledger_entries.amount_minor ELSE 0 END)'

      LedgerEntry
        .where(entry_type: STAKE_TYPES + RETURN_TYPES)
        .joins(:user)
        .group('users.id', 'users.email')
        .select(
          'users.id   AS user_id',
          'users.email AS email',
          "#{staked_expr} AS total_staked",
          "#{returned_expr} AS total_returned"
        )
        .order(Arel.sql("#{returned_expr} - #{staked_expr} DESC"))
        .limit(50)
    end
  end
end
