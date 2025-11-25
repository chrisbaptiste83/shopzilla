
class CartsController < ApplicationController
  def show
    @cart = session[:cart] || {}
    @products = Product.where(id: @cart.keys)
  end

  def add
    product = Product.find_by(id: params[:product_id])

    unless product
      redirect_to root_path, alert: "Product not found."
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

