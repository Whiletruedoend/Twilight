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

ActiveRecord::Schema.define(version: 2021_09_14_071104) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.bigint "user_id"
    t.string "name"
    t.string "color"
    t.integer "sort"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "channels", force: :cascade do |t|
    t.bigint "platform_id"
    t.bigint "user_id"
    t.boolean "enabled"
    t.string "token"
    t.string "room"
    t.json "options"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["platform_id"], name: "index_channels_on_platform_id"
    t.index ["user_id"], name: "index_channels_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.string "text"
    t.json "identifier"
    t.bigint "post_id"
    t.bigint "user_id"
    t.bigint "platform_user_id"
    t.boolean "has_attachments", default: false
    t.boolean "is_edited", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["platform_user_id"], name: "index_comments_on_platform_user_id"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "contents", force: :cascade do |t|
    t.string "text"
    t.bigint "post_id"
    t.bigint "user_id"
    t.boolean "has_attachments", default: false
    t.index ["post_id"], name: "index_contents_on_post_id"
    t.index ["user_id"], name: "index_contents_on_user_id"
  end

  create_table "invite_codes", force: :cascade do |t|
    t.bigint "user_id"
    t.string "code"
    t.boolean "is_enabled"
    t.boolean "is_single_use"
    t.integer "usages", default: 0
    t.integer "max_usages"
    t.datetime "expires_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_invite_codes_on_user_id"
  end

  create_table "item_tags", force: :cascade do |t|
    t.boolean "enabled", default: true
    t.bigint "tag_id"
    t.string "item_type"
    t.bigint "item_id"
    t.index ["item_type", "item_id"], name: "index_item_tags_on_item_type_and_item_id"
    t.index ["tag_id"], name: "index_item_tags_on_tag_id"
  end

  create_table "platform_posts", force: :cascade do |t|
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "platform_id"
    t.bigint "post_id"
    t.json "identifier"
    t.bigint "content_id"
    t.bigint "channel_id"
    t.index ["channel_id"], name: "index_platform_posts_on_channel_id"
    t.index ["content_id"], name: "index_platform_posts_on_content_id"
    t.index ["platform_id"], name: "index_platform_posts_on_platform_id"
    t.index ["post_id"], name: "index_platform_posts_on_post_id"
  end

  create_table "platform_users", force: :cascade do |t|
    t.json "identifier"
    t.bigint "platform_id"
    t.index ["platform_id"], name: "index_platform_users_on_platform_id"
  end

  create_table "platforms", force: :cascade do |t|
    t.string "title"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title"
    t.integer "privacy", default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "user_id"
    t.bigint "category_id"
    t.index ["category_id"], name: "index_posts_on_category_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.boolean "enabled_by_default"
    t.integer "sort"
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
    t.json "options", default: {}
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "platform_posts", "platforms"
  add_foreign_key "posts", "categories", on_delete: :nullify
end
