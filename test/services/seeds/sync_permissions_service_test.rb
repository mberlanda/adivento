require "test_helper"

class Seeds::SyncPermissionsServiceTest < ActiveSupport::TestCase
  test "syncs catalog permissions and deactivates unknown keys" do
    stale_permission = Permission.create!(
      key: "stale.permission",
      description: "legacy",
      active: true
    )

    permission = Permission.find_or_create_by!(key: "backoffice.access")
    permission.update!(description: "old", active: false)

    Seeds::SyncPermissionsService.call!

    permission.reload
    stale_permission.reload

    assert_equal "Access backoffice web and admin operations", permission.description
    assert_equal true, permission.active
    assert_equal false, stale_permission.active
  end
end
