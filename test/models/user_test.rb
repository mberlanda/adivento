require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'normalizes email' do
    user = User.create!(email: '  NewUser@Example.com ', password: 'password123', role: :player, active: true)

    assert_equal 'newuser@example.com', user.email
  end

  test 'creates wallet automatically' do
    user = User.create!(email: 'autowallet@example.com', password: 'password123', role: :player, active: true)

    assert_predicate user.wallet, :present?
  end
end
