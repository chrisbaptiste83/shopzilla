class HomeController < ApplicationController
  def index
    random_order = ActiveRecord::Base.connection.adapter_name == "MySQL" ? "RAND()" : "RANDOM()"
    @random_categories = Category.where(id: Category.joins(:products).distinct.select(:id))
                                  .order(Arel.sql(random_order))
                                  .limit(6)
    @featured_products = Product.where(is_available: true)
                                 .includes(:images_attachments)
                                 .order(created_at: :desc)
                                 .limit(3)
    @mosaic_products = Product.where(
      id: Product.where(is_available: true).joins(:images_attachments).distinct.select(:id)
    )
                               .order(Arel.sql(random_order))
                               .limit(5)
  end

  def about
  end

  def contact
  end
end
