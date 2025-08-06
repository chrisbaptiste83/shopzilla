
class CheckoutController < ApplicationController
  def create
    product = Product.find(params[:product_id])

    session = Stripe::Checkout::Session.create(
      payment_method_types: ['card'],
      line_items: [{
        price_data: {
          currency: 'usd',
          product_data: {
            name: product.title
          },
          unit_amount: (product.price * 100).to_i, # Stripe expects cents
        },
        quantity: 1,
      }],
      mode: 'payment',
      success_url: "#{root_url}success",
      cancel_url: "#{root_url}cancel"
    )

    redirect_to session.url, allow_other_host: true
  end
end

