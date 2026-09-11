class MedicalRecord < ApplicationRecord
  belongs_to :appointment
  belongs_to :doctor
  belongs_to :patient

  # PHI at rest. The columns hold ciphertext; a database dump, a replica or a backup
  # tape is useless without the Active Record Encryption keys.
  encrypts :notes
  encrypts :diagnosis

  validates :diagnosis, presence: true

  scope :visible_to, lambda { |user|
    case user&.role
    when "admin" then all
    when "doctor" then where(doctor_id: user.doctor&.id)
    when "patient" then where(patient_id: user.patient&.id)
    else none
    end
  }
end
