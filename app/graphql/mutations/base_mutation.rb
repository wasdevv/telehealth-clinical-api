module Mutations
  # Every mutation in this schema answers with the same two fields: `resource` (the thing
  # that was created or changed, null when nothing was) and `errors` (empty when it
  # worked). A client writes one error-handling path and it holds for all of them.
  class BaseMutation < GraphQL::Schema::Mutation
    argument_class Types::BaseArgument
    field_class Types::BaseField
    object_class Types::BaseObject

    def self.resource_field(type)
      field :resource, type, null: true, description: "The affected record, or null when the mutation failed"
      field :errors, [Types::MutationErrorType], null: false, description: "Empty when the mutation succeeded"
    end

    private

    def current_user
      context[:current_user]
    end

    # Interactors already fail with the `{ field, code, message }` shape, so there is
    # nothing to translate here; this only unwraps the context.
    def payload_for(result, resource_key)
      if result.success?
        { resource: result.public_send(resource_key), errors: [] }
      else
        { resource: nil, errors: Array(result.errors) }
      end
    end
  end
end
