require "sidekiq/web"

Rails.application.routes.draw do
  # The whole clinical domain is behind this one endpoint. There are deliberately no
  # REST routes for appointments, patients, doctors or medical records.
  post "/graphql", to: "graphql#execute"

  devise_for :users,
             path: "auth",
             path_names: { sign_in: "login", sign_out: "logout" },
             controllers: {
               sessions: "users/sessions",
               omniauth_callbacks: "users/omniauth_callbacks"
             }

  namespace :auth do
    scope path: "2fa", controller: "two_factor", as: "two_factor" do
      post :setup
      post :enable
      post :verify
    end
  end

  # Queue introspection is a development convenience. In production Sidekiq Web would
  # need its own authentication, which this service does not provide.
  mount Sidekiq::Web => "/sidekiq" if Rails.env.development?

  get "up" => "rails/health#show", as: :rails_health_check
end
