require "test_helper"

class AuthorizationServiceTest < ActiveSupport::TestCase
  test "role permission allows action" do
    assert AuthorizationService.allowed?(user: users(:moderator), permission_key: "market.leg.create")
  end

  test "ad hoc deny overrides role permission" do
    UserGrant.create!(
      user: users(:moderator),
      permission: permissions(:market_settle),
      allow: false,
      reason: "incident",
      granted_by: users(:admin)
    )

    assert_not AuthorizationService.allowed?(user: users(:moderator), permission_key: "market.settle")
  end

  test "ad hoc allow grants access even without role permission" do
    assert AuthorizationService.allowed?(user: users(:player), permission_key: "backoffice.access")
  end
end
