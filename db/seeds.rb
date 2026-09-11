# Demo data for development only. The passwords below are printed in the README on
# purpose: they exist so someone can open the API and try it, and they must never be
# loaded anywhere that holds a real patient.
#
# This returns rather than aborts: `db:prepare` runs seeds whenever it creates the
# database, so aborting here takes the whole production container down on first boot.
unless Rails.env.development?
  Rails.logger.info("Skipping seeds: the demo data is development-only.")
  return
end

DEMO_PASSWORD = "telehealth-demo-2026".freeze

admin = User.create_with(password: DEMO_PASSWORD, role: "admin").find_or_create_by!(email: "admin@example.com")

doctors = [
  { email: "dr.reyes@example.com", full_name: "Dr. Ana Reyes", specialty: "cardiology" },
  { email: "dr.okafor@example.com", full_name: "Dr. Chidi Okafor", specialty: "dermatology" }
].map do |attrs|
  user = User.create_with(password: DEMO_PASSWORD, role: "doctor").find_or_create_by!(email: attrs[:email])
  Doctor.find_or_create_by!(user: user) do |doctor|
    doctor.full_name = attrs[:full_name]
    doctor.specialty = attrs[:specialty]
  end
end

patients = [
  { email: "sam.patient@example.com", full_name: "Sam Rivera", phone: "+15551230001" },
  { email: "kai.patient@example.com", full_name: "Kai Lindqvist", phone: "" }
].map do |attrs|
  user = User.create_with(password: DEMO_PASSWORD, role: "patient").find_or_create_by!(email: attrs[:email])
  Patient.find_or_create_by!(user: user) do |patient|
    patient.full_name = attrs[:full_name]
    patient.phone = attrs[:phone]
  end
end

doctors.each do |doctor|
  (1..10).each do |day|
    start = (Date.current + day).in_time_zone.change(hour: 9) + (doctor.id % 3).hours
    Availability.find_or_create_by!(doctor: doctor, starts_at: start, ends_at: start + 30.minutes)
  end
end

Rails.logger.debug do
  "Seeded #{User.count} users, #{doctors.size} doctors, #{patients.size} patients, #{Availability.count} slots."
end
Rails.logger.debug { "Every demo account uses the password: #{DEMO_PASSWORD}" }
Rails.logger.debug { "Admin: #{admin.email}" }
