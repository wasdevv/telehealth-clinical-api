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

ActiveRecord::Schema[8.1].define(version: 2026_01_01_000008) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "appointments", force: :cascade do |t|
    t.bigint "availability_id", null: false
    t.string "cancellation_reason"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.bigint "doctor_id", null: false
    t.datetime "ends_at", null: false
    t.virtual "external_ref", type: :string, as: "('appointment:'::text || id)", stored: true
    t.bigint "patient_id", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.index ["availability_id"], name: "index_appointments_on_active_availability", unique: true, where: "((status)::text = ANY ((ARRAY['scheduled'::character varying, 'confirmed'::character varying])::text[]))"
    t.index ["doctor_id", "starts_at", "ends_at"], name: "index_appointments_on_doctor_id_and_starts_at_and_ends_at"
    t.index ["external_ref"], name: "index_appointments_on_external_ref", unique: true
    t.index ["patient_id", "starts_at"], name: "index_appointments_on_patient_id_and_starts_at"
    t.index ["status", "starts_at"], name: "index_appointments_on_status_and_starts_at"
    t.check_constraint "ends_at > starts_at", name: "appointments_time_order_check"
    t.check_constraint "status::text = ANY (ARRAY['scheduled'::character varying, 'confirmed'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])", name: "appointments_status_check"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.bigint "resource_id", null: false
    t.string "resource_type", null: false
    t.bigint "user_id", null: false
    t.index ["resource_type", "resource_id", "created_at"], name: "idx_on_resource_type_resource_id_created_at_e4025139fc"
    t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
  end

  create_table "availabilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "doctor_id", null: false
    t.datetime "ends_at", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["doctor_id", "starts_at", "ends_at"], name: "index_availabilities_on_doctor_id_and_starts_at_and_ends_at", unique: true
    t.check_constraint "ends_at > starts_at", name: "availabilities_time_order_check"
  end

  create_table "doctors", force: :cascade do |t|
    t.integer "consultation_fee_cents", default: 15000, null: false
    t.datetime "created_at", null: false
    t.string "full_name", null: false
    t.string "specialty", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["specialty"], name: "index_doctors_on_specialty"
    t.index ["user_id"], name: "index_doctors_on_user_id", unique: true
    t.check_constraint "consultation_fee_cents > 0", name: "doctors_fee_positive_check"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["exp"], name: "index_jwt_denylists_on_exp"
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "medical_records", force: :cascade do |t|
    t.bigint "appointment_id", null: false
    t.datetime "created_at", null: false
    t.text "diagnosis"
    t.bigint "doctor_id", null: false
    t.text "notes"
    t.bigint "patient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_medical_records_on_appointment_id", unique: true
    t.index ["doctor_id", "created_at"], name: "index_medical_records_on_doctor_id_and_created_at"
    t.index ["patient_id", "created_at"], name: "index_medical_records_on_patient_id_and_created_at"
  end

  create_table "patients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "full_name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_patients_on_user_id", unique: true
  end

# Could not dump table "users" because of following ArgumentError
#   wrong number of arguments (given 2, expected 1)


  add_foreign_key "appointments", "availabilities"
  add_foreign_key "appointments", "doctors"
  add_foreign_key "appointments", "patients"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "availabilities", "doctors"
  add_foreign_key "doctors", "users"
  add_foreign_key "medical_records", "appointments"
  add_foreign_key "medical_records", "doctors"
  add_foreign_key "medical_records", "patients"
  add_foreign_key "patients", "users"
end
