# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_27_221019) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.integer "actor_id", null: false
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.text "reason"
    t.bigint "target_id", null: false
    t.string "target_type", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["target_type", "target_id"], name: "index_audit_events_on_target_type_and_target_id"
  end

  create_table "bets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "fee_minor", null: false
    t.bigint "market_id", null: false
    t.bigint "market_leg_id", null: false
    t.bigint "net_stake_minor", null: false
    t.integer "odds_minor", null: false
    t.bigint "potential_payout_minor", null: false
    t.bigint "stake_minor", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["market_id", "status"], name: "index_bets_on_market_id_and_status"
    t.index ["market_id"], name: "index_bets_on_market_id"
    t.index ["market_leg_id"], name: "index_bets_on_market_leg_id"
    t.index ["user_id"], name: "index_bets_on_user_id"
  end

  create_table "betslip_executions", force: :cascade do |t|
    t.json "bet_ids", default: [], null: false
    t.bigint "betslip_quote_id", null: false
    t.datetime "created_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["betslip_quote_id"], name: "index_betslip_executions_on_betslip_quote_id", unique: true
    t.index ["user_id"], name: "index_betslip_executions_on_user_id"
  end

  create_table "betslip_quotes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "idempotency_key", null: false
    t.json "items", default: [], null: false
    t.integer "status", default: 0, null: false
    t.bigint "total_stake_minor", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["idempotency_key"], name: "index_betslip_quotes_on_idempotency_key", unique: true
    t.index ["status"], name: "index_betslip_quotes_on_status"
    t.index ["user_id"], name: "index_betslip_quotes_on_user_id"
  end

  create_table "faucet_requests", force: :cascade do |t|
    t.bigint "amount_minor", null: false
    t.datetime "created_at", null: false
    t.text "note"
    t.integer "reviewed_by_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["reviewed_by_id"], name: "index_faucet_requests_on_reviewed_by_id"
    t.index ["status"], name: "index_faucet_requests_on_status"
    t.index ["user_id"], name: "index_faucet_requests_on_user_id"
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.bigint "amount_minor", null: false
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.string "entry_type", null: false
    t.json "metadata", default: {}, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["actor_id"], name: "index_ledger_entries_on_actor_id"
    t.index ["entry_type"], name: "index_ledger_entries_on_entry_type"
    t.index ["user_id"], name: "index_ledger_entries_on_user_id"
  end

  create_table "market_legs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.integer "market_id", null: false
    t.integer "odds_minor", default: 5000, null: false
    t.datetime "updated_at", null: false
    t.index ["market_id", "label"], name: "index_market_legs_on_market_id_and_label", unique: true
    t.index ["market_id"], name: "index_market_legs_on_market_id"
  end

  create_table "market_templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "default_duration_hours", default: 24, null: false
    t.text "default_legs"
    t.text "description"
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_market_templates_on_key", unique: true
  end

  create_table "markets", force: :cascade do |t|
    t.string "category", default: "other", null: false
    t.datetime "close_at"
    t.datetime "created_at", null: false
    t.integer "created_by_id", null: false
    t.text "description", null: false
    t.integer "fee_bps", default: 100, null: false
    t.integer "last_fill_price_cents"
    t.bigint "liability_cap_minor", default: 100000, null: false
    t.bigint "liquidity_subsidy_minor"
    t.float "lmsr_b_parameter"
    t.bigint "lmsr_q_no", default: 0, null: false
    t.bigint "lmsr_q_yes", default: 0, null: false
    t.string "mechanism_type", default: "fixed_odds", null: false
    t.bigint "parimutuel_pool_no_minor", default: 0, null: false
    t.bigint "parimutuel_pool_yes_minor", default: 0, null: false
    t.string "question", null: false
    t.text "resolution_criteria"
    t.string "resolution_source"
    t.integer "settled_by_id"
    t.string "settled_outcome"
    t.integer "spread_fee_bps"
    t.integer "status", default: 0, null: false
    t.boolean "structure_locked", default: false, null: false
    t.json "tags", default: [], null: false
    t.integer "takeout_bps"
    t.integer "taker_fee_bps"
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_markets_on_category"
    t.index ["created_by_id"], name: "index_markets_on_created_by_id"
    t.index ["settled_by_id"], name: "index_markets_on_settled_by_id"
    t.index ["status"], name: "index_markets_on_status"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "cancelled_quantity", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "filled_quantity", default: 0, null: false
    t.bigint "market_id", null: false
    t.bigint "market_leg_id", null: false
    t.integer "price_cents", null: false
    t.integer "quantity", null: false
    t.string "side", null: false
    t.integer "status", default: 0, null: false
    t.integer "time_in_force", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["market_id", "side", "price_cents", "status"], name: "index_orders_book"
    t.index ["market_id"], name: "index_orders_on_market_id"
    t.index ["market_leg_id"], name: "index_orders_on_market_leg_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
  end

  create_table "price_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "market_id", null: false
    t.string "mechanism_type", null: false
    t.datetime "recorded_at", null: false
    t.json "snapshot_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["market_id", "recorded_at"], name: "index_price_snapshots_on_market_id_and_recorded_at"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "permission_id", null: false
    t.string "role_name", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_name", "permission_id"], name: "index_role_permissions_on_role_name_and_permission_id", unique: true
  end

  create_table "user_grants", force: :cascade do |t|
    t.boolean "allow", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.bigint "granted_by_id", null: false
    t.bigint "permission_id", null: false
    t.text "reason"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["granted_by_id"], name: "index_user_grants_on_granted_by_id"
    t.index ["permission_id"], name: "index_user_grants_on_permission_id"
    t.index ["user_id", "permission_id", "created_at"], name: "index_user_grants_on_user_id_and_permission_id_and_created_at"
    t.index ["user_id"], name: "index_user_grants_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "wallets", force: :cascade do |t|
    t.string "asset_code", default: "ADIV", null: false
    t.bigint "available_minor", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "reserved_minor", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_wallets_on_user_id", unique: true
  end

  add_foreign_key "audit_events", "users", column: "actor_id"
  add_foreign_key "bets", "market_legs"
  add_foreign_key "bets", "markets"
  add_foreign_key "bets", "users"
  add_foreign_key "betslip_executions", "betslip_quotes"
  add_foreign_key "betslip_executions", "users"
  add_foreign_key "betslip_quotes", "users"
  add_foreign_key "faucet_requests", "users"
  add_foreign_key "faucet_requests", "users", column: "reviewed_by_id"
  add_foreign_key "ledger_entries", "users"
  add_foreign_key "ledger_entries", "users", column: "actor_id"
  add_foreign_key "market_legs", "markets"
  add_foreign_key "markets", "users", column: "created_by_id"
  add_foreign_key "markets", "users", column: "settled_by_id"
  add_foreign_key "orders", "market_legs"
  add_foreign_key "orders", "markets"
  add_foreign_key "orders", "users"
  add_foreign_key "price_snapshots", "markets"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "user_grants", "permissions"
  add_foreign_key "user_grants", "users"
  add_foreign_key "user_grants", "users", column: "granted_by_id"
  add_foreign_key "wallets", "users"
end
