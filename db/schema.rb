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

ActiveRecord::Schema[7.2].define(version: 2026_06_02_154144) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "vector"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

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
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "certificate_requests", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "cert_type", null: false
    t.integer "status", default: 0, null: false
    t.date "requested_at", null: false
    t.date "expected_ready_at"
    t.date "ready_at"
    t.text "notes"
    t.string "reference_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "admin_notes"
    t.index ["reference_number"], name: "index_certificate_requests_on_reference_number", unique: true
    t.index ["status"], name: "index_certificate_requests_on_status"
    t.index ["user_id", "cert_type"], name: "index_certificate_requests_on_user_id_and_cert_type"
    t.index ["user_id", "status"], name: "index_certificate_requests_on_user_id_and_status"
    t.index ["user_id"], name: "index_certificate_requests_on_user_id"
  end

  create_table "certificate_types", force: :cascade do |t|
    t.string "key", null: false
    t.string "label", null: false
    t.text "description"
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_certificate_types_on_active"
    t.index ["key"], name: "index_certificate_types_on_key", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_conversations_on_user_id_and_created_at"
    t.index ["user_id", "status"], name: "index_conversations_on_user_id_and_status"
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "document_chunks", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.text "content", null: false
    t.integer "chunk_index", null: false
    t.vector "embedding", limit: 1536
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "chunk_index"], name: "index_document_chunks_on_document_id_and_chunk_index", unique: true
    t.index ["document_id"], name: "index_document_chunks_on_document_id"
    t.index ["embedding"], name: "index_document_chunks_on_embedding_ivfflat", opclass: :vector_cosine_ops, using: :ivfflat
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "uploaded_by_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "doc_type", null: false
    t.integer "status", default: 0, null: false
    t.text "processing_error"
    t.integer "chunks_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "cert_type"
    t.index ["cert_type"], name: "index_documents_on_cert_type"
    t.index ["doc_type"], name: "index_documents_on_doc_type"
    t.index ["status"], name: "index_documents_on_status"
    t.index ["uploaded_by_id", "created_at"], name: "index_documents_on_uploaded_by_id_and_created_at"
    t.index ["uploaded_by_id"], name: "index_documents_on_uploaded_by_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.integer "role", null: false
    t.text "content", default: "", null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id", "role"], name: "index_messages_on_conversation_id_and_role"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.integer "role", default: 0, null: false
    t.string "employee_id", default: "", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["employee_id"], name: "index_users_on_employee_id", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "certificate_requests", "users"
  add_foreign_key "conversations", "users"
  add_foreign_key "document_chunks", "documents"
  add_foreign_key "documents", "users", column: "uploaded_by_id"
  add_foreign_key "messages", "conversations"
end
