class Appointment < ApplicationRecord
  STATUSES = %w[scheduled confirmed completed cancelled].freeze
  # The statuses that hold a slot. The partial unique index in the schema uses the same
  # list; changing one without the other reopens the double-booking hole.
  ACTIVE_STATUSES = %w[scheduled confirmed].freeze

  belongs_to :patient
  belongs_to :doctor
  belongs_to :availability
  has_one :medical_record, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :starting_from, ->(time) { time.present? ? where(starts_at: time..) : all }

  # Every read of clinical data starts from a participant-scoped relation, so an id that
  # belongs to someone else is simply not found rather than found-and-refused.
  scope :visible_to, lambda { |user|
    case user&.role
    when "admin" then all
    when "doctor" then where(doctor_id: user.doctor&.id)
    when "patient" then where(patient_id: user.patient&.id)
    else none
    end
  }

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def reminder_time
    starts_at - 24.hours
  end
end
