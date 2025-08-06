class HomeController < ApplicationController
  def index
    @featured_products = Product.where(is_available: true).limit(3)
  end
end
