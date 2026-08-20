class HomeController < ApplicationController
  def index
    random_order = ActiveRecord::Base.connection.adapter_name == "MySQL" ? "RAND()" : "RANDOM()"
    @random_categories = Category.where(id: Category.joins(:products).distinct.select(:id))
                                  .order(Arel.sql(random_order))
                                  .limit(6)
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
