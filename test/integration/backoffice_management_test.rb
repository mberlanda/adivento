require "test_helper"

class BackofficeManagementTest < ActionDispatch::IntegrationTest
  test "admin can view permissions matrix" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }
    get "/backoffice/permissions"

    assert_response :success
    assert_match "Role Permission Matrix", response.body
  end

  test "admin can update role permission with reason" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }

    permission = permissions(:market_update)
    assert_difference("AuditEvent.count", 1) do
      patch "/backoffice/permissions/#{permission.id}", params: {
        role_name: "moderator",
        enabled: true,
        reason: "delegation"
      }
    end

    assert_response :redirect
    assert RolePermission.exists?(role_name: "moderator", permission: permission)
  end

  test "admin can create ad hoc deny grant" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }

    assert_difference("UserGrant.count", 1) do
      post "/backoffice/grants", params: {
        user_id: users(:moderator).id,
        permission_id: permissions(:market_settle).id,
        allow: false,
        reason: "cooldown"
      }
    end

    assert_response :redirect
  end

  test "admin can create template" do
    post "/signin", params: { email: users(:admin).email, password: "password123" }

    assert_difference("MarketTemplate.count", 1) do
      post "/backoffice/templates", params: {
        key: "election_binary",
        name: "Election Binary",
        description: "Election model",
        default_legs: "YES,NO",
        default_duration_hours: 72,
        active: true,
        reason: "new catalog"
      }
    end

    assert_response :redirect
  end
end
