require 'test_helper'

# Runs real threads against committed rows, so transactional fixtures are disabled
# and the fresh user/bets are cleaned up explicitly in teardown.
class BetPlacementConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @market = markets(:open_market)
    @leg = @market.market_legs.find_by!(label: 'YES')
    @user = User.create!(email: "race-#{SecureRandom.hex(6)}@example.com", password: 'password123', role: :player)
    @user.wallet.update!(available_minor: 1000, reserved_minor: 0)
  end

  teardown do
    Bet.where(user: @user).delete_all
    LedgerEntry.where(user: @user).delete_all
    AuditEvent.where(actor: @user).delete_all
    @user.destroy
  end

  test 'two concurrent placements on a one-bet balance create exactly one bet' do
    barrier = Concurrent::CyclicBarrier.new(2)
    results = []
    mutex = Mutex.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          # Each thread loads the user independently, mirroring two separate requests
          # that each read wallet balance from the database.
          user = User.find(@user.id)
          barrier.wait
          outcome =
            begin
              BetPlacementService.place!(user: user, market: @market, market_leg: @leg, stake_minor: 1000)
              :ok
            rescue StandardError
              :rejected
            end
          mutex.synchronize { results << outcome }
        end
      end
    end
    threads.each(&:join)

    assert_equal 1, results.count(:ok), 'exactly one concurrent placement should succeed'
    assert_equal 1, Bet.where(user: @user).count, 'only one bet should be created'
    assert_equal 0, @user.wallet.reload.available_minor, 'wallet debited exactly once'
  end
end
