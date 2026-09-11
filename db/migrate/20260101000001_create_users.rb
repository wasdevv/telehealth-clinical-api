class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :encrypted_password, null: false, default: ""

      t.string :role, null: false, default: "patient"

      # Google OAuth identity. Both columns are set together or not at all.
      t.string :provider
      t.string :uid

      # TOTP. The secret is encrypted at rest by Active Record Encryption; recovery
      # codes are stored only as SHA256 digests, so a database dump cannot replay them.
      t.text :otp_secret
      t.boolean :otp_enabled, null: false, default: false
      t.jsonb :otp_recovery_code_digests, null: false, default: []

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, %i[provider uid], unique: true, where: "provider IS NOT NULL"

    add_check_constraint :users, "role IN ('patient', 'doctor', 'admin')", name: "users_role_check"
    add_check_constraint :users,
                         "(provider IS NULL AND uid IS NULL) OR (provider IS NOT NULL AND uid IS NOT NULL)",
                         name: "users_oauth_identity_complete_check"
  end
end
