module AuthHelpers
  def jwt_for(user)
    token, _payload = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    token
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{jwt_for(user)}" }
  end
end

RSpec.configure { |config| config.include AuthHelpers, type: :request }
