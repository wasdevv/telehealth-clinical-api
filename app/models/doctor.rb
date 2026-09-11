class Doctor < ApplicationRecord
  belongs_to :user
  has_many :availabilities, dependent: :destroy
  has_many :appointments, dependent: :restrict_with_exception
  has_many :medical_records, dependent: :restrict_with_exception

  validates :full_name, :specialty, presence: true
  validates :consultation_fee_cents, numericality: { greater_than: 0, only_integer: true }

  scope :with_specialty, ->(specialty) { specialty.present? ? where(specialty: specialty) : all }
end
