
class CartsController < ApplicationController
  def show
    @cart = session[:cart] || {}
    @products = Product.where(id: @cart.keys, is_available: true).with_attached_images
    available_ids = @products.map { |product| product.id.to_s }
    @cart.delete_if { |product_id, _quantity| !available_ids.include?(product_id) }
    @subtotal = @products.sum { |product| product.price * @cart.fetch(product.id.to_s, 0).to_i }
  end

  def add
    product = Product.find_by(id: params[:product_id], is_available: true)

    unless product
      redirect_to products_path, alert: "This product is not available."
      return
    end

    session[:cart] ||= {}
    session[:cart][product.id.to_s] ||= 0
    session[:cart][product.id.to_s] += 1
    redirect_back(fallback_location: root_path, notice: "#{product.title} added to cart.")
  end

  def remove
    product = Product.find_by(id: params[:product_id])

    unless product
      redirect_to root_path, alert: "Product not found."
      return
    end

    session[:cart]&.delete(product.id.to_s)
    redirect_back(fallback_location: root_path, notice: "#{product.title} removed from cart.")
  end

  def clear
    session[:cart] = {}
    redirect_back(fallback_location: root_path)
  end
end
