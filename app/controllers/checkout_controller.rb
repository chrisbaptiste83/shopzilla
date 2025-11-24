class CheckoutController < ApplicationController
  before_action :authenticate_user!

  def create
    # Determine products to checkout
    if params[:product_id].present?
      products = [Product.find(params[:product_id])]
    else
      cart = session[:cart] || {}
      products = Product.where(id: cart.keys)
      if products.empty?
        redirect_to cart_path, alert: "Your cart is empty."
        return
      end
    end

    # Build line_items for Stripe
    line_items = products.map do |product|
      quantity = params[:product_id].present? ? 1 : session[:cart][product.id.to_s].to_i
      {
        price_data: {
          currency: "usd",
          product_data: {
            name: product.title,
            description: product.description.to_plain_text.squish
          },
          unit_amount: (product.price * 100).to_i
        },
        quantity: quantity
      }
    end

    # Attach product IDs in metadata as comma-separated
    metadata_products = products.map(&:id).join(",")

    # Clear cart if it was a cart purchase
    session[:cart] = {} unless params[:product_id].present?

    # Create Stripe Checkout session
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

