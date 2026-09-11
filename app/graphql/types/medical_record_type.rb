module Types
  # Reaching this type at all means the participant check already passed, because the only
  # route to it is AppointmentType#medical_record, which looks the record up through
  # MedicalRecord.visible_to. What is enforced *here* is the audit trail: reading PHI is
  # itself an event HIPAA expects to see recorded.
  class MedicalRecordType < BaseObject
    description "The clinical record of a consultation. Reading its PHI fields is audited."

    field :id, ID, null: false
    field :diagnosis, String, null: true, description: "PHI — encrypted at rest, access audited"
    field :notes, String, null: true, description: "PHI — encrypted at rest, access audited"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    batch_belongs_to :doctor, type: DoctorType, null: false
    batch_belongs_to :patient, type: PatientType, null: false

    def diagnosis
      audit_phi_access!
      object.diagnosis
    end

    def notes
      audit_phi_access!
      object.notes
    end

    private

    # One row per record per request. A query asking for both `notes` and `diagnosis` is
    # one act of reading one chart, and logging it twice would make the trail harder to
    # read, not more complete.
    #
    # If the audit row cannot be written, the PHI is not returned. Failing closed is the
    # conservative reading of "log every access": unlogged access must not happen.
    def audit_phi_access!
      seen = context[:audited_medical_record_ids] ||= Set.new
      return unless seen.add?(object.id)

      AuditLog.record!(
        user: context[:current_user],
        resource: object,
        action: "medical_record.read",
        ip: context[:ip]
      )
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("PHI access audit failed: #{e.class}")
      raise GraphQL::ExecutionError.new(
        "Access to this record could not be audited and was therefore refused.",
        extensions: { "code" => "audit_unavailable" }
      )
    end
  end
end
