class HomeController < ApplicationController
  def index
    @categories = Category.all
    @featured_products = Product.where(is_available: true).limit(3)
  end
  
  def about
  end

  def contact
  end


end
