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

  resources :products
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

  get "up" => "rails/health#show", as: :rails_health_check

  root to: "home#index"
end
