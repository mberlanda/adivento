require 'test_helper'

class JsonWebTokenTest < ActiveSupport::TestCase
  test 'encodes and decodes payload' do
    token = JsonWebToken.encode({ user_id: users(:player).id })
    payload = JsonWebToken.decode(token)

    assert_equal users(:player).id, payload['user_id']
  end
end
