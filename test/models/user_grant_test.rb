require 'test_helper'

class UserGrantTest < ActiveSupport::TestCase
  test 'active_now excludes expired grants' do
    grant = UserGrant.create!(
      user: users(:moderator),
      permission: permissions(:market_create),
      allow: true,
      reason: 'temporary',
      granted_by: users(:admin),
      expires_at: 1.hour.ago
    )

    assert_not_includes UserGrant.active_now, grant
  end
end
