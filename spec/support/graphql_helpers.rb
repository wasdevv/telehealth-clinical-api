module GraphqlHelpers
  def graphql(query, user: nil, variables: {}, headers: {})
    post "/graphql",
         params: { query: query, variables: variables }.to_json,
         headers: { "Content-Type" => "application/json" }
           .merge(user ? auth_headers(user) : {})
           .merge(headers)
    JSON.parse(response.body)
  end

  def graphql_data(body, *path)
    path.reduce(body.fetch("data")) { |acc, key| acc&.fetch(key, nil) }
  end
end

RSpec.configure { |config| config.include GraphqlHelpers, type: :request }
