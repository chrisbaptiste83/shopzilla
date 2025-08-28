Rails.application.routes.draw do
  post '/webhooks/stripe', to: 'webhooks#stripe'
  get '/downloads/:token', to: 'downloads#show', as: 'secure_download'
  get "pages/success"
  get "pages/cancel"
  get "profiles/show"
  get "profiles/edit"
  get "profiles/update"
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resource :profile, only: [:show, :edit, :update]
  resources :checkout, only: [:create]
    

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  root to: "home#index"
  resources :products 
  get "success", to: "pages#success"
  get "cancel", to: "pages#cancel"
  
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
