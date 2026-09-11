module Types
  class AppointmentStatusEnum < BaseEnum
    description "Lifecycle of an appointment"

    Appointment::STATUSES.each { |status| value status.upcase, value: status }
  end
end
