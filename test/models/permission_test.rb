require 'test_helper'

class PermissionTest < ActiveSupport::TestCase
  test 'fixture keys are unique' do
    keys = Permission.pluck(:key)

    assert_equal keys.uniq.sort, keys.sort
  end
end
