module Catalogs
  class MarketTemplateCatalog
    TEMPLATES = [
      {
        key: 'binary_yes_no',
        name: 'Binary Yes/No',
        description: 'Simple yes or no market template',
        default_legs: %w[YES NO],
        default_duration_hours: 24,
        active: true
      },
      {
        key: 'sports_winner',
        name: 'Sports Winner',
        description: 'Head to head outcome template',
        default_legs: %w[TEAM_A TEAM_B],
        default_duration_hours: 12,
        active: true
      },
      {
        key: 'macro_direction',
        name: 'Macro Direction',
        description: 'Up/down directional event template',
        default_legs: %w[UP DOWN],
        default_duration_hours: 48,
        active: true
      }
    ].freeze

    def self.keys
      TEMPLATES.pluck(:key)
    end
  end
end
