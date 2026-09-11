class Patient < ApplicationRecord
  belongs_to :user
  has_many :appointments, dependent: :restrict_with_exception
  has_many :medical_records, dependent: :restrict_with_exception

  validates :full_name, presence: true

  def contact_phone
    phone.to_s
  end
end
