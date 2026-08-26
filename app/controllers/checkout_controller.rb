class CheckoutController < ApplicationController
  before_action :authenticate_user!

  def create
    # Determine products to checkout
    if params[:product_id].present?
      product = Product.find_by(id: params[:product_id], is_available: true)
      unless product
        redirect_to products_path, alert: "This product is not available."
        return
      end
      @products = [ product ]
    else
      cart = session[:cart] || {}
      @products = Product.where(id: cart.keys, is_available: true)
      if @products.empty?
        redirect_to cart_path, alert: "Your cart is empty."
        return
      end
      if @products.size != cart.keys.uniq.size
        redirect_to cart_path, alert: "One or more products are no longer available."
        return
      end
    end

    quantities_by_product_id = build_quantities(@products)

    if quantities_by_product_id.values.any? { |q| q <= 0 }
      redirect_to cart_path, alert: "Invalid quantities in cart."
      return
    end

    # Check if any product is physical
    if @products.any?(&:shippable)
      @quantities_by_product_id = quantities_by_product_id
      total = @products.sum { |product| product.price * quantities_by_product_id.fetch(product.id.to_s) }
      @order = Order.new(user: current_user, status: "pending", total: total) # Temporary order
      @order.build_shipping_address
      render :shipping
    else
      # Existing logic for digital products
      line_items = @products.map do |product|
        quantity = quantities_by_product_id.fetch(product.id.to_s)
        {
          price_data: {
            currency: "usd",
            product_data: { name: product.title },
            unit_amount: (product.price * 100).to_i
          },
          quantity: quantity
        }
      end

      metadata_products = quantities_by_product_id.keys.join(",")
      session[:cart] = {} unless params[:product_id].present?

      session_checkout = Stripe::Checkout::Session.create(
        payment_method_types: [ "card" ],
        line_items: line_items,
        mode: "payment",
        success_url: pages_success_url + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: pages_cancel_url,
        metadata: {
          user_id: current_user.id,
          product_ids: metadata_products,
          product_quantities: quantities_by_product_id.to_json
        }
      )
      redirect_to session_checkout.url, allow_other_host: true
    end
  end

  def process_shipping_address
    @order = Order.new(order_params)
    @order.user = current_user
    @order.status = "pending"

    @quantities_by_product_id = parsed_quantities(params[:product_quantities])
    if @quantities_by_product_id.empty?
      redirect_to cart_path, alert: "Your cart is empty or invalid."
      return
    end

    product_ids = @quantities_by_product_id.keys
    products = Product.where(id: product_ids, is_available: true).to_a
    if products.size != product_ids.size
      redirect_to cart_path, alert: "One or more products are no longer available."
      return
    end

    total = products.sum { |product| product.price * @quantities_by_product_id.fetch(product.id.to_s) }
    @order.total = total

    if @order.save
      # Build line_items for Stripe
      line_items = products.map do |product|
        {
          price_data: {
            currency: "usd",
            product_data: { name: product.title },
            unit_amount: (product.price * 100).to_i
          },
          quantity: @quantities_by_product_id.fetch(product.id.to_s)
        }
      end

      # Create Stripe Checkout session
      session_checkout = Stripe::Checkout::Session.create(
        payment_method_types: [ "card" ],
        line_items: line_items,
        mode: "payment",
        success_url: pages_success_url + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: pages_cancel_url,
        metadata: {
          user_id: current_user.id,
          order_id: @order.id, # Pass order_id to webhook
          product_ids: products.map(&:id).join(","),
          product_quantities: @quantities_by_product_id.to_json
        }
      )

      session[:cart] = {}
      redirect_to session_checkout.url, allow_other_host: true
    else
      # Re-render form with errors
      @products = products
      render :shipping, status: :unprocessable_entity
    end
  end

  private

  def order_params
    params.require(:order).permit(
      shipping_address_attributes: [
        :full_name, :street_address, :city, :state, :zip_code, :country
      ]
    )
  end

  def build_quantities(products)
    products.index_with do |product|
      params[:product_id].present? ? 1 : session.dig(:cart, product.id.to_s).to_i
    end.transform_keys { |product| product.id.to_s }
  end

  def parsed_quantities(raw_quantities)
    JSON.parse(raw_quantities.to_s).each_with_object({}) do |(product_id, quantity), result|
      next unless product_id.to_s.match?(/\A\d+\z/)

      normalized_quantity = quantity.to_i
      result[product_id.to_s] = normalized_quantity if normalized_quantity.between?(1, 99)
    end
  rescue JSON::ParserError, NoMethodError
    {}
  end
end
