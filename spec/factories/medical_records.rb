FactoryBot.define do
  factory :medical_record do
    appointment
    doctor { appointment.doctor }
    patient { appointment.patient }
    diagnosis { "Essential hypertension" }
    notes { "Blood pressure 150/95. Start 5mg amlodipine, review in six weeks." }
  end
end
