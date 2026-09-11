module Types
  class BaseConnection < GraphQL::Types::Relay::BaseConnection
    edge_nullable(false)
    edges_nullable(false)
  end
end
