require "test_helper"

class FaucetRequestTest < ActiveSupport::TestCase
  test "amount must be positive" do
    request = FaucetRequest.new(user: users(:player), amount_minor: 0, status: :pending)
    assert_not request.valid?
  end
end
