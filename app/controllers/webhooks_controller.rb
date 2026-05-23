class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def stripe
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    endpoint_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
    rescue JSON::ParserError, Stripe::SignatureVerificationError
      return render json: { error: "Invalid payload or signature" }, status: 400
    end

    case event["type"]
    when "checkout.session.completed"
      handle_successful_payment(event["data"]["object"])
    end

    render json: { status: "success" }
  end

  private

  def handle_successful_payment(session)
    user = User.find_by(id: session["metadata"]["user_id"])
    return unless user

    # Avoid duplicate orders
    return if Order.exists?(stripe_session_id: session["id"])

    ActiveRecord::Base.transaction do
      # Check if order already exists (for physical products with shipping address)
      if session["metadata"]["order_id"].present?
        order = Order.find(session["metadata"]["order_id"])
        order.update!(
          status: "completed",
          stripe_session_id: session["id"]
        )
      else
        # Create new order (for digital products)
        order = Order.create!(
          user: user,
          total: session["amount_total"] / 100.0,
          status: "completed",
          stripe_session_id: session["id"]
        )
      end

      quantities_by_product_id = extract_quantities(session["metadata"])
      product_ids = quantities_by_product_id.keys.map(&:to_i)
      product_ids = session["metadata"]["product_ids"].split(",").map(&:to_i) if product_ids.empty? && session["metadata"]["product_ids"].present?
      products = Product.where(id: product_ids)

      Payment.create!(
        order: order,
        amount: session["amount_total"] / 100.0,
        stripe_payment_id: session["payment_intent"],
        status: "completed"
      )

      products.each do |product|
        quantity = quantities_by_product_id.fetch(product.id.to_s, 1).to_i
        OrderItem.create!(
          order: order,
          product: product,
          quantity: quantity,
          unit_price: product.price
        )

        # Download access is only for digital products.
        unless product.physical_product
          DownloadAccess.create!(
            user: user,
            product: product,
            order: order,
            expires_at: 30.days.from_now,
            download_count: 0
          )
        end
      end
    end
  end

  def extract_quantities(metadata)
    raw_quantities = metadata["product_quantities"]
    return {} if raw_quantities.blank?

    JSON.parse(raw_quantities)
  rescue JSON::ParserError
    {}
  end
end
