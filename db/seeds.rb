# ── Users ────────────────────────────────────────────────────────────────────

users_data = [
  { email: 'admin@adivento.local',     role: :admin,     balance_minor: 0 },
  { email: 'moderator@adivento.local', role: :moderator, balance_minor: 0 },
  { email: 'player@adivento.local',    role: :player,    balance_minor: 250_000 },
  { email: 'alice@adivento.local',     role: :player,    balance_minor: 180_000 },
  { email: 'bob@adivento.local',       role: :player,    balance_minor: 95_000 }
]

users_data.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.password = 'password123' if user.new_record?
  user.role     = attrs[:role]
  user.active   = true
  user.save!
  user.wallet.update!(available_minor: attrs[:balance_minor], reserved_minor: 0)
end

Seeds::SyncPermissionsService.call!
Seeds::SyncRolePermissionsService.call!
Seeds::SyncMarketTemplatesService.call!

admin  = User.find_by!(email: 'admin@adivento.local')
player = User.find_by!(email: 'player@adivento.local')
alice  = User.find_by!(email: 'alice@adivento.local')

# ── Markets ───────────────────────────────────────────────────────────────────

def create_market!(admin, attrs)
  market = Market.find_or_initialize_by(question: attrs[:question])
  return market unless market.new_record?

  market.assign_attributes(
    description: attrs[:description],
    mechanism_type: attrs[:mechanism_type] || 'fixed_odds',
    category: attrs[:category] || 'other',
    tags: attrs[:tags] || [],
    fee_bps: attrs[:fee_bps] || 0,
    liability_cap_minor: attrs[:liability_cap] || 500_000,
    taker_fee_bps: attrs[:taker_fee_bps],
    liquidity_subsidy_minor: attrs[:liquidity_subsidy],
    spread_fee_bps: attrs[:spread_fee_bps],
    takeout_bps: attrs[:takeout_bps],
    created_by: admin
  )
  market.save!

  legs = attrs[:legs] || [{ label: 'YES', odds: 5000 }, { label: 'NO', odds: 5000 }]
  legs.each do |leg|
    market.market_legs.find_or_create_by!(label: leg[:label]) do |l|
      l.odds_minor = leg[:odds]
      l.active     = true
    end
  end

  market.update!(status: :open) if %i[open settled].include?(attrs[:status])

  if attrs[:status] == :settled && attrs[:outcome]
    SettlementService.settle!(market: market.reload, outcome: attrs[:outcome], actor: admin)
  end

  HotStorage::MarketSnapshotProjector.project!(market: market.reload, reason: 'seed')
  market.reload
end

markets_config = [
  # ── Sports / Fixed-odds ───────────────────────────────────────────────────
  {
    question: 'Will Argentina win the 2026 FIFA World Cup?',
    description: 'Argentina to win the 2026 FIFA World Cup hosted across USA, Canada, and Mexico.',
    category: 'sports', tags: %w[world-cup football argentina],
    mechanism_type: 'fixed_odds', fee_bps: 200, liability_cap: 500_000,
    legs: [{ label: 'YES', odds: 2200 }, { label: 'NO', odds: 7800 }],
    status: :open
  },
  {
    question: 'Will the Lakers win the 2025-26 NBA Championship?',
    description: 'Los Angeles Lakers to win the 2025-26 NBA Finals.',
    category: 'sports', tags: %w[nba basketball lakers],
    mechanism_type: 'fixed_odds', fee_bps: 250, liability_cap: 300_000,
    legs: [{ label: 'YES', odds: 1500 }, { label: 'NO', odds: 8500 }],
    status: :open
  },
  {
    question: 'Will Manchester City finish top of the 2025-26 Premier League?',
    description: 'Manchester City to win the 2025-26 Premier League title.',
    category: 'sports', tags: %w[premier-league football man-city],
    mechanism_type: 'fixed_odds', fee_bps: 200, liability_cap: 400_000,
    legs: [{ label: 'YES', odds: 3000 }, { label: 'NO', odds: 7000 }],
    status: :settled, outcome: 'YES'
  },
  {
    question: 'Will Novak Djokovic win the 2026 Australian Open?',
    description: 'Novak Djokovic to win the men\'s singles title at the 2026 Australian Open.',
    category: 'sports', tags: %w[tennis djokovic grand-slam],
    mechanism_type: 'fixed_odds', fee_bps: 300, liability_cap: 200_000,
    legs: [{ label: 'YES', odds: 2800 }, { label: 'NO', odds: 7200 }],
    status: :open
  },

  # ── Economics / CLOB ─────────────────────────────────────────────────────
  {
    question: 'Will the Fed cut rates at the September 2026 FOMC meeting?',
    description: 'Federal Reserve to reduce the federal funds rate target range at the September 17-18, 2026 FOMC meeting.',
    category: 'economics', tags: %w[fed rates fomc macro],
    mechanism_type: 'clob', taker_fee_bps: 50, liability_cap: 1_000_000,
    legs: [{ label: 'YES', odds: 4500 }, { label: 'NO', odds: 5500 }],
    status: :open
  },
  {
    question: 'Will US CPI year-over-year be below 2.5% in June 2026?',
    description: 'US Bureau of Labor Statistics CPI-U (all items) YoY change for June 2026 to be reported below 2.5%.',
    category: 'economics', tags: %w[cpi inflation macro bls],
    mechanism_type: 'clob', taker_fee_bps: 50, liability_cap: 800_000,
    legs: [{ label: 'YES', odds: 3800 }, { label: 'NO', odds: 6200 }],
    status: :open
  },
  {
    question: 'Will the S&P 500 close above 6000 on September 30, 2026?',
    description: 'S&P 500 index (SPX) to close above 6000 points on the last trading day of Q3 2026.',
    category: 'economics', tags: %w[sp500 equities stocks],
    mechanism_type: 'clob', taker_fee_bps: 50, liability_cap: 1_500_000,
    legs: [{ label: 'YES', odds: 5200 }, { label: 'NO', odds: 4800 }],
    status: :open
  },
  {
    question: 'Will the ECB cut rates before the Fed in Q3 2026?',
    description: 'European Central Bank to announce a rate cut before the US Federal Reserve does in Q3 2026.',
    category: 'economics', tags: %w[ecb fed rates europe macro],
    mechanism_type: 'clob', taker_fee_bps: 60, liability_cap: 600_000,
    legs: [{ label: 'YES', odds: 3500 }, { label: 'NO', odds: 6500 }],
    status: :draft
  },

  # ── Technology / LMSR ────────────────────────────────────────────────────
  {
    question: 'Will Apple release a foldable iPhone before end of 2026?',
    description: 'Apple to commercially launch a foldable iPhone model by December 31, 2026.',
    category: 'technology', tags: %w[apple iphone foldable hardware],
    mechanism_type: 'lmsr', liquidity_subsidy: 200_000, spread_fee_bps: 150, liability_cap: 1,
    legs: [{ label: 'YES', odds: 3000 }, { label: 'NO', odds: 7000 }],
    status: :open
  },
  {
    question: 'Will any AI model score above 95% on the MMLU benchmark by end of 2026?',
    description: 'At least one publicly released AI model to achieve above 95% on the MMLU benchmark ' \
                 'by December 31, 2026.',
    category: 'technology', tags: %w[ai llm benchmark mmlu],
    mechanism_type: 'lmsr', liquidity_subsidy: 150_000, spread_fee_bps: 100, liability_cap: 1,
    legs: [{ label: 'YES', odds: 6000 }, { label: 'NO', odds: 4000 }],
    status: :open
  },
  {
    question: 'Will a quantum computer solve a commercially useful problem before mid-2027?',
    description: 'A quantum computer to demonstrably solve a real-world commercially valuable problem, ' \
                 'verified by a peer-reviewed publication before June 30, 2027.',
    category: 'technology', tags: %w[quantum computing hardware research],
    mechanism_type: 'lmsr', liquidity_subsidy: 120_000, spread_fee_bps: 120, liability_cap: 1,
    legs: [{ label: 'YES', odds: 2000 }, { label: 'NO', odds: 8000 }],
    status: :draft
  },

  # ── Politics / Parimutuel ────────────────────────────────────────────────
  {
    question: 'Will the UK Conservative Party win more than 100 seats in the next general election?',
    description: 'UK Conservative Party to win at least 101 seats in the next UK General Election.',
    category: 'politics', tags: %w[uk conservatives election parliament],
    mechanism_type: 'parimutuel', takeout_bps: 1000, liability_cap: 1,
    legs: [{ label: 'YES', odds: 4500 }, { label: 'NO', odds: 5500 }],
    status: :open
  },
  {
    question: 'Will Emmanuel Macron remain President of France through 2027?',
    description: 'Emmanuel Macron to remain in office as President of France until the end of his current term in May 2027.',
    category: 'politics', tags: %w[france macron president europe],
    mechanism_type: 'parimutuel', takeout_bps: 1200, liability_cap: 1,
    legs: [{ label: 'YES', odds: 7500 }, { label: 'NO', odds: 2500 }],
    status: :settled, outcome: 'YES'
  },

  # ── Entertainment / Fixed-odds ───────────────────────────────────────────
  {
    question: 'Will Dune: Messiah gross over $800M worldwide at the box office?',
    description: 'Dune: Messiah (Part Three) to achieve $800M or more in worldwide theatrical gross.',
    category: 'entertainment', tags: %w[dune film box-office cinema],
    mechanism_type: 'fixed_odds', fee_bps: 300, liability_cap: 200_000,
    legs: [{ label: 'YES', odds: 5500 }, { label: 'NO', odds: 4500 }],
    status: :open
  },
  {
    question: 'Will Taylor Swift release a new studio album in 2026?',
    description: 'Taylor Swift to officially release a new studio album (not a re-recording) in calendar year 2026.',
    category: 'entertainment', tags: %w[taylor-swift music album pop],
    mechanism_type: 'fixed_odds', fee_bps: 250, liability_cap: 150_000,
    legs: [{ label: 'YES', odds: 6000 }, { label: 'NO', odds: 4000 }],
    status: :open
  },
  {
    question: 'Will a video game adaptation win the Best Picture Oscar at the 2027 Academy Awards?',
    description: 'A film adapted from a video game to win Best Picture at the 97th Academy Awards in 2027.',
    category: 'entertainment', tags: %w[oscars film gaming adaptation],
    mechanism_type: 'fixed_odds', fee_bps: 200, liability_cap: 100_000,
    legs: [{ label: 'YES', odds: 800 }, { label: 'NO', odds: 9200 }],
    status: :draft
  }
]

markets = markets_config.map { |cfg| create_market!(admin, cfg) }

# ── Demo bets for player (showcases profile page) ────────────────────────────

open_markets = markets.select(&:open?)

# Place a few bets for the player on open markets
open_markets.first(5).each_with_index do |market, i|
  next if market.bets.exists?(user: player)

  leg = market.market_legs.first
  stake = (i + 1) * 500

  begin
    BetPlacementService.place!(
      user: player,
      market: market,
      market_leg: leg,
      stake_minor: stake
    )
  rescue StandardError => e
    Rails.logger.debug { "  Skipping bet on #{market.question.truncate(40)}: #{e.message}" }
  end
end

# Alice has a few bets too
open_markets.first(3).each do |market|
  next if market.bets.exists?(user: alice)

  leg = market.market_legs.last
  begin
    BetPlacementService.place!(
      user: alice,
      market: market,
      market_leg: leg,
      stake_minor: 1000
    )
  rescue StandardError => e
    Rails.logger.debug { "  Skipping Alice bet: #{e.message}" }
  end
end

Rails.logger.debug { "Seeded #{Market.count} markets, #{Bet.count} bets, #{User.count} users." }
