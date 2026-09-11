class TelehealthClinicalApiSchema < GraphQL::Schema
  mutation Types::MutationType
  query Types::QueryType

  # Installs the lazy resolution BatchLoader needs and clears its cache between requests,
  # so one request's loaded records can never leak into the next.
  use BatchLoader::GraphQL

  # A public GraphQL endpoint accepts queries the server author never wrote, so the cost
  # of a query has to be bounded before it runs, not after. Depth stops recursive
  # traversals (appointment → doctor → availabilities → doctor → ...); complexity stops a
  # wide, shallow query asking for a hundred connections at once; the page size caps how
  # much any one connection can return.
  #
  # The complexity ceiling is calibrated, not guessed: a realistic client query — `me`
  # plus a page of 25 appointments with doctor and patient on each — measures 361, so a
  # limit of 200 would have rejected ordinary use while every spec still passed. 1000
  # leaves roughly 3x headroom and still refuses `myAppointments(first: 500)`, which
  # costs 1002 before a single row is read.
  max_depth 10
  max_complexity 1000
  # default_max_page_size is the cap, not a suggestion: graphql-ruby clamps `first`/`last`
  # to it, so a client asking for 10_000 records gets 25.
  default_max_page_size 25

  # Errors that should read as "not found" rather than as a server fault.
  rescue_from(ActiveRecord::RecordNotFound) do |_err, _obj, _args, _ctx, _field|
    raise GraphQL::ExecutionError.new("Record not found", extensions: { "code" => "not_found" })
  end

  def self.unauthorized_object(_error)
    raise GraphQL::ExecutionError.new(
      "You are not allowed to see this.",
      extensions: { "code" => "forbidden" }
    )
  end

  def self.type_error(err, _context)
    raise GraphQL::ExecutionError.new("Unexpected value for #{err.field&.name}", extensions: { "code" => "type_error" })
  end
end
