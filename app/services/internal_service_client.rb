require "net/http"
require "uri"
require "json"

# Shared transport for the internal services this API talks to. Timeouts are short on
# purpose: a booking request is a person waiting, and a slow billing service must become
# a retry in the background rather than a hung web worker.
class InternalServiceClient
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  class Error < StandardError; end

  # Worth trying again later: timeouts, refused connections, DNS, 5xx.
  class RetryableError < Error; end

  # The request was understood and refused. Retrying the identical body changes nothing.
  class UnprocessableError < Error; end

  # The deployment is misconfigured. Failing loudly beats silently not billing anyone.
  class ConfigurationError < Error; end

  def initialize(base_url: ENV.fetch("DJANGO_BILLING_URL", nil), token: ENV.fetch("INTERNAL_SERVICE_TOKEN", nil))
    @base_url = base_url.to_s
    @token = token.to_s
    raise ConfigurationError, "DJANGO_BILLING_URL is not set" if @base_url.empty?
    raise ConfigurationError, "INTERNAL_SERVICE_TOKEN is not set" if @token.empty?
  end

  private

  attr_reader :base_url, :token

  def post(path, payload, accept:, headers: {})
    uri = build_uri(path)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request["Authorization"] = "Token #{token}"
    headers.each { |key, value| request[key] = value }
    request.body = JSON.generate(payload)

    response = perform(uri, request)
    handle(response, accept: accept, path: path)
  end

  def perform(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http.request(request)
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET,
         Errno::EHOSTUNREACH, SocketError, IOError => e
    # The exception class is safe to log; the request body is not — it carries PHI
    # and the patient's email, and the Authorization header carries the shared token.
    raise RetryableError, "#{self.class.name}: #{e.class}"
  end

  def handle(response, accept:, path:)
    code = response.code.to_i
    return parse_body(response) if accept.include?(code)
    raise RetryableError, "#{self.class.name}: #{path} returned #{code}" if code >= 500

    raise UnprocessableError, "#{self.class.name}: #{path} returned #{code}"
  end

  # A body that is not a JSON object is not something to index into. Parsing "null" or
  # "7" succeeds, so checking the class is the only way to know we got a document.
  def parse_body(response)
    parsed = JSON.parse(response.body.to_s)
    parsed.is_a?(Hash) ? parsed : {}
  rescue JSON::ParserError
    {}
  end

  def build_uri(path)
    URI.join("#{base_url.chomp('/')}/", path.delete_prefix("/"))
  end
end
