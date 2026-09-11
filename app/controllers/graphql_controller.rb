class GraphqlController < ApplicationController
  # The whole domain is behind this action, so authentication is not per-field or
  # per-resolver: an unauthenticated request never reaches the schema at all.
  before_action :authenticate_user!

  def execute
    result = TelehealthClinicalApiSchema.execute(
      params[:query],
      variables: prepare_variables(params[:variables]),
      operation_name: params[:operationName],
      context: {
        current_user: current_user,
        # Carried into the context because the audit trail records where a PHI read came
        # from, and a resolver has no access to the request.
        ip: request.remote_ip
      }
    )

    render json: result
  rescue GraphQL::ParseError, GraphQL::ExecutionError => e
    render json: { errors: [{ message: e.message }], data: nil }, status: :bad_request
  end

  private

  # Variables arrive as a JSON object, a string of JSON, already-parsed params, or not
  # at all.
  def prepare_variables(raw)
    case raw
    when nil then {}
    when String then variables_from_json(raw)
    when ActionController::Parameters then raw.to_unsafe_h
    when Hash then raw
    else raise GraphQL::ExecutionError, "Unexpected variables format"
    end
  end

  # JSON.parse happily returns a String or an Integer for valid JSON that is not an
  # object, so the class has to be checked before anything indexes into it.
  def variables_from_json(raw)
    return {} if raw.blank?

    parsed = JSON.parse(raw)
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    raise GraphQL::ExecutionError, "Variables are not valid JSON"
  end
end
