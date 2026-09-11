module Types
  # One shape for every mutation error. `code` is the stable, machine-readable half;
  # `message` is for humans and may change wording without breaking a client.
  class MutationErrorType < BaseObject
    description "A reason a mutation did not succeed"

    field :field, String, null: true, description: "Input field the error belongs to, if any"
    field :code, String, null: false, description: "Stable machine-readable identifier"
    field :message, String, null: false, description: "Human-readable explanation"
  end
end
