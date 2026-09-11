module Types
  class BaseObject < GraphQL::Schema::Object
    edge_type_class(Types::BaseEdge)
    connection_type_class(Types::BaseConnection)
    field_class Types::BaseField

    # Declares a belongs_to association as a batched field.
    #
    # Why this is needed: a GraphQL resolver runs once per parent object, so
    # `{ myAppointments { doctor { fullName } } }` over 50 appointments calls the
    # `doctor` resolver 50 times. A plain `object.doctor` issues one SELECT each — the
    # N+1 — and there is no `includes` to hang it on, because the server does not know
    # which associations a query will ask for until it is already resolving them.
    #
    # BatchLoader defers each call: instead of a record it returns a promise holding the
    # foreign key. GraphQL-Ruby resolves the whole level before touching the next, so by
    # the time the promises are forced, all 50 ids are known and one
    # `WHERE id IN (...)` answers all of them. 50 queries become 1.
    #
    # The cache key is scoped by model and association so a Doctor promise and a Patient
    # promise for the same numeric id can never collide.
    def self.batch_belongs_to(name, type:, null: true, model: nil, foreign_key: nil)
      model_name = (model || name.to_s.classify).to_s
      key = foreign_key || :"#{name}_id"

      field name, type, null: null

      define_method(name) do
        id = object.public_send(key)
        return nil if id.nil?

        BatchLoader::GraphQL.for(id).batch(key: "#{model_name}/#{key}") do |ids, loader|
          model_name.constantize.where(id: ids).find_each { |record| loader.call(record.id, record) }
        end
      end
    end

    private

    def current_user
      context[:current_user]
    end
  end
end
