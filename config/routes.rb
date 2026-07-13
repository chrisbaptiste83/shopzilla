Rails.application.routes.draw do
  resources :orders, only: [ :index, :show, :create ]

  post "/webhooks/stripe", to: "webhooks#stripe"

  get "/downloads/:token", to: "downloads#show", as: :secure_download

  resource :checkout, only: [ :create ], controller: "checkout"
  post "checkout/process_shipping_address", to: "checkout#process_shipping_address", as: :process_shipping_address

  get "pages/success"
  get "pages/cancel"

  resource :profile, only: [ :show, :edit, :update ]

  get "dashboard", to: "dashboard#show", as: :dashboard
  get "dashboard/orders", to: "dashboard#orders", as: :dashboard_orders
  get "dashboard/downloads", to: "dashboard#downloads", as: :dashboard_downloads
  get "dashboard/wishlist", to: "dashboard#wishlist", as: :dashboard_wishlist

  resources :products do
    resources :reviews, only: [ :create, :destroy ]
  end
  resources :categories
  devise_for :users, controllers: {
    sessions:      "users/sessions",
    registrations: "users/registrations",
    omniauth_callbacks: "users/omniauth_callbacks"
  }
  ActiveAdmin.routes(self)

  resources :wishlist_items, only: [ :index, :create, :destroy ]

  get "about", to: "home#about"
  get "contact", to: "home#contact"
  post "contact", to: "home#contact"

  resource :cart, only: [ :show ] do
    collection do
      post :add
      delete :remove
      delete :clear
    end
  end

  # Turbo Native Path Configurations
  get "configurations/ios_v1",     to: "configurations#ios_v1",     defaults: { format: :json }
  get "configurations/android_v1", to: "configurations#android_v1", defaults: { format: :json }

  get "up" => "rails/health#show", as: :rails_health_check
  root to: "home#index"

  match "/404", to: "errors#not_found",    via: :all
  match "/422", to: "errors#unprocessable", via: :all
  match "/500", to: "errors#server_error",  via: :all
end
