require "test_helper"

class Seeds::SyncRolePermissionsServiceTest < ActiveSupport::TestCase
  setup do
    Seeds::SyncPermissionsService.call!
  end

  test "creates desired role permissions and prunes extra mappings" do
    permission_manage = Permission.find_by!(key: "permission.manage")
    RolePermission.find_or_create_by!(role_name: "player", permission_id: permission_manage.id)

    Seeds::SyncRolePermissionsService.call!

    assert_equal false, RolePermission.exists?(role_name: "player", permission_id: permission_manage.id)

    market_create = Permission.find_by!(key: "market.create")
    assert_equal true, RolePermission.exists?(role_name: "admin", permission_id: market_create.id)
  end

  test "raises when catalog exposes invalid roles" do
    service = Seeds::SyncRolePermissionsService
    singleton = service.singleton_class

    singleton.class_eval do
      alias_method :original_catalog_roles_for_test, :catalog_roles
      define_method(:catalog_roles) { ["admin", "ghost"] }
      private :catalog_roles
    end

    error = assert_raises(RuntimeError) do
      service.call!
    end

    singleton.class_eval do
      remove_method :catalog_roles
      alias_method :catalog_roles, :original_catalog_roles_for_test
      remove_method :original_catalog_roles_for_test
      private :catalog_roles
    end

    assert_match "Invalid roles in permission catalog", error.message
  end
end
