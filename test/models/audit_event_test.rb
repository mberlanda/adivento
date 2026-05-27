require 'test_helper'

class AuditEventTest < ActiveSupport::TestCase
  test 'requires action' do
    event = audit_events(:market_update)
    event.action = nil

    assert_not event.valid?
  end
end
