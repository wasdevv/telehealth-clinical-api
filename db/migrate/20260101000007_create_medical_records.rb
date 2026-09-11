class CreateMedicalRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :medical_records do |t|
      t.references :appointment, null: false, foreign_key: true, index: { unique: true }
      t.references :doctor, null: false, foreign_key: true, index: false
      t.references :patient, null: false, foreign_key: true, index: false

      # PHI. Ciphertext in the column; see MedicalRecord#encrypts.
      t.text :notes
      t.text :diagnosis

      t.timestamps
    end

    add_index :medical_records, %i[patient_id created_at]
    add_index :medical_records, %i[doctor_id created_at]
  end
end
