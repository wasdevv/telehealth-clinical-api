class CreatePatients < ActiveRecord::Migration[8.1]
  def change
    create_table :patients do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :full_name, null: false
      t.string :phone
      t.date :date_of_birth

      t.timestamps
    end
  end
end
