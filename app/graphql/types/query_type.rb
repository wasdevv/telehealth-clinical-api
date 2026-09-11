module Types
  class QueryType < BaseObject
    description "Read side of the clinical domain"

    field :me, UserType, null: false,
                         description: "The authenticated account"

    field :appointment, AppointmentType, null: true,
                                         description: "One appointment the caller participates in" do
      argument :id, ID, required: true
    end

    field :my_appointments, AppointmentType.connection_type, null: false,
                                                             description: "The caller's appointments, soonest first" do
      argument :status, AppointmentStatusEnum, required: false
      argument :from, GraphQL::Types::ISO8601DateTime, required: false,
                                                       description: "Only appointments starting at or after this time"
    end

    field :doctors, DoctorType.connection_type, null: false,
                                                description: "The clinician directory, visible to any authenticated account" do
      argument :specialty, String, required: false
    end

    def me
      current_user
    end

    def appointment(id:)
      Appointment.visible_to(current_user).find_by(id: id)
    end

    def my_appointments(status: nil, from: nil)
      scope = Appointment.visible_to(current_user).starting_from(from)
      scope = scope.where(status: status) if status.present?
      # id breaks ties so paging is stable when two appointments start at the same instant.
      scope.order(:starts_at, :id)
    end

    def doctors(specialty: nil)
      Doctor.with_specialty(specialty).order(:full_name, :id)
    end
  end
end
