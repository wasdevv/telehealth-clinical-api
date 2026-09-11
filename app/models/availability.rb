class Availability < ApplicationRecord
  belongs_to :doctor
  has_many :appointments, dependent: :restrict_with_exception

  validates :starts_at, :ends_at, presence: true
  validate :ends_after_start

  scope :upcoming, -> { where(starts_at: Time.current..) }
  scope :unbooked, lambda {
    where.not(id: Appointment.active.select(:availability_id))
  }

  def booked?
    appointments.active.exists?
  end

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, "must be after starts_at")
  end
end
