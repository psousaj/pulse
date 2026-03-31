Rails.application.routes.draw do
  get "login" => "sessions#new"
  delete "logout" => "sessions#destroy"
  match "auth/:provider/callback", to: "sessions#create", via: %i[get post]
  match "auth/failure", to: "sessions#failure", via: %i[get post]

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#index"

  get "status" => "public/status_pages#index"

  post "api/heartbeat/:token" => "api/heartbeats#create"

  namespace :api do
    namespace :v1 do
      resources :services, only: [ :index, :show ]
      resources :incidents, only: [ :index, :show ]
    end
  end
end
