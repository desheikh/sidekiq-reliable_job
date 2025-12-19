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

ActiveRecord::Schema[7.2].define(version: 2024_12_15_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "reliable_job_outbox", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "enqueued_at"
    t.string "jid", null: false
    t.string "job_class", null: false
    t.json "payload", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["jid"], name: "index_reliable_job_outbox_on_jid", unique: true
    t.index ["status", "id"], name: "index_reliable_job_outbox_on_status_and_id"
  end
end
