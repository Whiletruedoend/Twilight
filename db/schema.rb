# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_12_06_150217) do

  create_table "item_tags", force: :cascade do |t|
    t.boolean "enabled", default: true
    t.integer "tag_id"
    t.string "item_type"
    t.integer "item_id"
    t.index ["item_type", "item_id"], name: "index_item_tags_on_item_type_and_item_id"
    t.index ["tag_id"], name: "index_item_tags_on_tag_id"
  end

  create_table "platform_posts", force: :cascade do |t|
    t.json "identifier"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "platform_id"
    t.integer "post_id"
    t.index ["platform_id"], name: "index_platform_posts_on_platform_id"
    t.index ["post_id"], name: "index_platform_posts_on_post_id"
  end

  create_table "platforms", force: :cascade do |t|
    t.string "title"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title"
    t.string "content"
    t.integer "access"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
  end

  create_table "users", force: :cascade do |t|
    t.string "login"
    t.string "rss_token", null: false
    t.boolean "is_admin"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "access_level", default: 2
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "platform_posts", "platforms"
end
