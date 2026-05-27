require 'test_helper'

module Seeds
  class SyncPermissionsServiceTest < ActiveSupport::TestCase
    test 'syncs catalog permissions and deactivates unknown keys' do
      stale_permission = Permission.create!(
        key: 'stale.permission',
        description: 'legacy',
        active: true
      )

      permission = Permission.find_or_create_by!(key: 'backoffice.access')
      permission.update!(description: 'old', active: false)

      Seeds::SyncPermissionsService.call!

      permission.reload
      stale_permission.reload

      assert_equal 'Access backoffice web and admin operations', permission.description
      assert permission.active
      assert_not stale_permission.active
    end
  end
end
