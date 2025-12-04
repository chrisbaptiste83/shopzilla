class CheckoutController < ApplicationController
  before_action :authenticate_user!

  def create
    # Determine products to checkout
    if params[:product_id].present?
      @products = [Product.find(params[:product_id])]
    else
      cart = session[:cart] || {}
      @products = Product.where(id: cart.keys)
      if @products.empty?
        redirect_to cart_path, alert: "Your cart is empty."
        return
      end
    end

    # Check if any product is physical
    if @products.any?(&:shippable)
      total = @products.sum(&:price)
      @order = Order.new(user: current_user, status: 'pending', total: total) # Temporary order
      @order.build_shipping_address
      render :shipping
    else
      # Existing logic for digital products
      line_items = @products.map do |product|
        quantity = params[:product_id].present? ? 1 : session[:cart][product.id.to_s].to_i
        {
          price_data: {
            currency: "usd",
            product_data: { name: product.title },
            unit_amount: (product.price * 100).to_i
          },
          quantity: quantity
        }
      end

      metadata_products = @products.map(&:id).join(",")
      session[:cart] = {} unless params[:product_id].present?

      session_checkout = Stripe::Checkout::Session.create(
        payment_method_types: ['card'],
        line_items: line_items,
        mode: "payment",
        success_url: pages_success_url + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: pages_cancel_url,
        metadata: {
          user_id: current_user.id,
          product_ids: metadata_products
        }
      )
      redirect_to session_checkout.url, allow_other_host: true
    end
  end

  def process_shipping_address
    @order = Order.new(order_params)
    @order.user = current_user
    @order.status = 'pending'

    # Manually re-associate products from IDs
    product_ids = params[:order][:product_ids].reject(&:blank?)
    products = Product.find(product_ids)

    total = products.sum(&:price)
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
          quantity: 1 # Assuming quantity of 1 for simplicity
        }
      end

      # Create Stripe Checkout session
      session_checkout = Stripe::Checkout::Session.create(
        payment_method_types: ['card'],
        line_items: line_items,
        mode: "payment",
        success_url: pages_success_url + "?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: pages_cancel_url,
        metadata: {
          user_id: current_user.id,
          order_id: @order.id, # Pass order_id to webhook
          product_ids: products.map(&:id).join(",")
        }
      )

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
end

