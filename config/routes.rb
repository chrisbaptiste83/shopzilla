
Rails.application.routes.draw do

  post '/webhooks/stripe', to: 'webhooks#stripe'

  get '/downloads/:token', to: 'downloads#show', as: :secure_download

  resource :checkout, only: [:create], controller: "checkout"

  get "pages/success"
  get "pages/cancel"
  
  resource :profile, only: [:show, :edit, :update]

  resources :products
  resources :categories
  # Devise + Admin
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  devise_for :users
  

  get "about", to: "home#about"
  get "contact", to: "home#contact"
  post "contact", to: "home#contact" 

  resource :cart, only: [:show] do
    collection do
      post :add
      delete :remove
      delete :clear
    end
  end


  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Root
  root to: "home#index"
end

