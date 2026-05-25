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

ActiveRecord::Schema[8.1].define(version: 2026_05_25_093260) do
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

  create_table "markets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_id", null: false
    t.text "description", null: false
    t.string "question", null: false
    t.integer "settled_by_id"
    t.string "settled_outcome"
    t.integer "status", default: 0, null: false
    t.boolean "structure_locked", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_markets_on_created_by_id"
    t.index ["settled_by_id"], name: "index_markets_on_settled_by_id"
    t.index ["status"], name: "index_markets_on_status"
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
  add_foreign_key "faucet_requests", "users"
  add_foreign_key "faucet_requests", "users", column: "reviewed_by_id"
  add_foreign_key "ledger_entries", "users"
  add_foreign_key "ledger_entries", "users", column: "actor_id"
  add_foreign_key "market_legs", "markets"
  add_foreign_key "markets", "users", column: "created_by_id"
  add_foreign_key "markets", "users", column: "settled_by_id"
  add_foreign_key "wallets", "users"
end
