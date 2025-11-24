
class CartsController < ApplicationController
  def show
    @cart = session[:cart] || {}
    @products = Product.where(id: @cart.keys)
  end

  def add
    session[:cart] ||= {}
    session[:cart][params[:product_id].to_s] ||= 0
    session[:cart][params[:product_id].to_s] += 1
    redirect_back(fallback_location: root_path)
  end

  def remove
    session[:cart]&.delete(params[:product_id].to_s)
    redirect_back(fallback_location: root_path)
  end

  def clear
    session[:cart] = {}
    redirect_back(fallback_location: root_path)
  end
end

