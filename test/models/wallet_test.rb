require "test_helper"

class WalletTest < ActiveSupport::TestCase
  test "computes total minor" do
    wallet = wallets(:player_wallet)
    wallet.available_minor = 1200
    wallet.reserved_minor = 300
    assert_equal 1500, wallet.total_minor
  end
end
