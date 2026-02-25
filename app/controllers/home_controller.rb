class HomeController < ApplicationController
  def index
    random_order = ActiveRecord::Base.connection.adapter_name == "MySQL" ? "RAND()" : "RANDOM()"
    @random_categories = Category.joins(:products)
                                  .distinct
                                  .order(Arel.sql(random_order))
                                  .limit(6)
    @featured_products = Product.where(is_available: true).limit(3)
  end
  
  def about
  end

  def contact
  end


end
