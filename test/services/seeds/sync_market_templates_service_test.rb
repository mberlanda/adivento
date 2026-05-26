require "test_helper"

class Seeds::SyncMarketTemplatesServiceTest < ActiveSupport::TestCase
  test "syncs market templates and deactivates unknown keys" do
    stale_template = MarketTemplate.create!(
      key: "legacy_template",
      name: "Legacy",
      description: "old",
      default_legs: ["YES", "NO"],
      default_duration_hours: 1,
      active: true
    )

    template = MarketTemplate.find_or_create_by!(key: "binary_yes_no")
    template.update!(name: "Outdated", active: false)

    Seeds::SyncMarketTemplatesService.call!

    template.reload
    stale_template.reload

    assert_equal "Binary Yes/No", template.name
    assert_equal true, template.active
    assert_equal false, stale_template.active
  end
end
