require 'test_helper'

class RolePermissionTest < ActiveSupport::TestCase
  test 'role permission must be unique per role' do
    duplicate = RolePermission.new(role_name: 'admin', permission: permissions(:market_create))

    assert_not duplicate.valid?
  end
end
