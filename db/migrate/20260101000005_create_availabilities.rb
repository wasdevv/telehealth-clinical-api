class CreateAvailabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :availabilities do |t|
      t.references :doctor, null: false, foreign_key: true, index: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false

      t.timestamps
    end

    # The slot-lookup index, and the reason a doctor cannot publish the same slot twice.
    add_index :availabilities, %i[doctor_id starts_at ends_at], unique: true

    add_check_constraint :availabilities, "ends_at > starts_at", name: "availabilities_time_order_check"
  end
end
