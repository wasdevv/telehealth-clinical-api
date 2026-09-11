require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:password) { "correct-horse-battery-staple" }
  let!(:user) { create(:user, email: "sam@example.com", password: password) }

  describe "POST /auth/login" do
    it "returns a bearer token for the right password" do
      post "/auth/login", params: { user: { email: "sam@example.com", password: password } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["token"]).to be_present
      expect(response.headers["Authorization"]).to start_with("Bearer ")
    end

    it "answers the same way for a wrong password and an unknown email" do
      post "/auth/login", params: { user: { email: "sam@example.com", password: "wrong" } }, as: :json
      wrong_password = [response.status, response.body]

      post "/auth/login", params: { user: { email: "nobody@example.com", password: password } }, as: :json
      unknown_email = [response.status, response.body]

      expect(wrong_password).to eq(unknown_email)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /graphql" do
    it "refuses a request with no token" do
      post "/graphql", params: { query: "{ me { id } }" }.to_json, headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses a token that has been revoked by logout" do
      post "/auth/login", params: { user: { email: "sam@example.com", password: password } }, as: :json
      token = response.parsed_body["token"]

      delete "/auth/logout", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:no_content)
      expect(JwtDenylist.count).to eq(1)

      post "/graphql",
           params: { query: "{ me { id } }" }.to_json,
           headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts a live token" do
      post "/graphql",
           params: { query: "{ me { id email } }" }.to_json,
           headers: { "Content-Type" => "application/json" }.merge(auth_headers(user))

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "me", "email")).to eq("sam@example.com")
    end
  end
end
