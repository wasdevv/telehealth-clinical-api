# Shared failure vocabulary. Every interactor fails with the same error shape the GraphQL
# mutations expose as `errors`, so a resolver never has to translate anything.
module ApplicationInteractor
  extend ActiveSupport::Concern

  included do
    include Interactor
  end

  private

  def fail_with(field, code, message)
    context.fail!(errors: [{ field: field&.to_s, code: code.to_s, message: message }])
  end

  def fail_with_record(record)
    context.fail!(errors: record.errors.map do |error|
      { field: error.attribute.to_s.camelize(:lower), code: error.type.to_s, message: error.full_message }
    end)
  end
end
