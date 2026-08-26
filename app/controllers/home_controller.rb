class HomeController < ApplicationController
  def index
    @featured_categories = Category.with_available_products.limit(6)
    @featured_products = Product.where(is_available: true)
                                 .with_attached_images
                                 .order(created_at: :desc)
                                 .limit(3)
  end

  def about
  end

  def contact
  end
end
