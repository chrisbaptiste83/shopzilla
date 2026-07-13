# frozen_string_literal: true

class ConfigurationsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :ios_v1, :android_v1 ], raise: false

  def ios_v1
    render json: {
      settings: {
        tabs: [
          { title: "Catalog", path: "/products", icon: "bag" },
          { title: "Wishlist", path: "/dashboard/wishlist", icon: "heart" },
          { title: "Orders", path: "/dashboard/orders", icon: "list" },
          { title: "Downloads", path: "/dashboard/downloads", icon: "arrow.down" }
        ]
      },
      rules: [
        {
          patterns: [ "/users/sign_in", "/users/sign_up" ],
          properties: {
            presentation: "modal"
          }
        },
        {
          patterns: [ "/cart", "/checkout" ],
          properties: {
            presentation: "modal"
          }
        }
      ]
    }
  end

  def android_v1
    ios_v1
  end
end
