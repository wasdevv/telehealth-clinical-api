class CreateDoctors < ActiveRecord::Migration[8.1]
  def change
    create_table :doctors do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :full_name, null: false
      t.string :specialty, null: false
      # The amount the billing service invoices for one consultation. A column rather
      # than a constant in BillingClient, so the money path has no magic number.
      t.integer :consultation_fee_cents, null: false, default: 15_000

      t.timestamps
    end

    add_index :doctors, :specialty
    add_check_constraint :doctors, "consultation_fee_cents > 0", name: "doctors_fee_positive_check"
  end
end
