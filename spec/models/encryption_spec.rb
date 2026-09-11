require "rails_helper"

# Calling `record.notes` proves nothing about what is on disk — it would pass even with
# encryption switched off. These read the raw column instead.
RSpec.describe "Encryption at rest" do
  def raw_column(table, column, id)
    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql_array(["SELECT #{column} FROM #{table} WHERE id = ?", id])
    )
  end

  it "stores medical record PHI as ciphertext" do
    record = create(:medical_record, diagnosis: "Type 2 diabetes", notes: "HbA1c 8.2%")

    expect(raw_column("medical_records", "diagnosis", record.id)).not_to include("diabetes")
    expect(raw_column("medical_records", "notes", record.id)).not_to include("8.2")
    expect(record.reload.diagnosis).to eq("Type 2 diabetes")
  end

  it "stores the TOTP secret as ciphertext" do
    user = create(:user)
    secret = user.start_totp_enrollment!

    expect(raw_column("users", "otp_secret", user.id)).not_to include(secret)
    expect(user.reload.otp_secret).to eq(secret)
  end

  it "never stores a recovery code in the clear" do
    user = create(:user)
    user.start_totp_enrollment!
    codes = user.enable_two_factor!(ROTP::TOTP.new(user.otp_secret).now)

    stored = raw_column("users", "otp_recovery_code_digests::text", user.id)
    codes.each { |code| expect(stored).not_to include(code) }
  end
end
