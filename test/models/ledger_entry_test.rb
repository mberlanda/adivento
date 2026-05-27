require 'test_helper'

class LedgerEntryTest < ActiveSupport::TestCase
  test 'direction must be credit or debit' do
    entry = ledger_entries(:grant_entry)
    entry.direction = 'invalid'

    assert_not entry.valid?
  end
end
