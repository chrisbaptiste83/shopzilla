class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def stripe
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = Rails.application.credentials.stripe[:webhook_secret]

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
    rescue JSON::ParserError, Stripe::SignatureVerificationError
      return render json: { error: 'Invalid payload or signature' }, status: 400
    end

    case event['type']
    when 'checkout.session.completed'
      handle_successful_payment(event['data']['object'])
    end

    render json: { status: 'success' }
  end

  private

  def handle_successful_payment(session)
    user = User.find_by(id: session['metadata']['user_id'])
    return unless user

    # Avoid duplicate orders
    return if Order.exists?(stripe_session_id: session['id'])

    order = Order.create!(
      user: user,
      total: session['amount_total'] / 100.0,
      status: 'completed',
      stripe_session_id: session['id']
    )

    product_ids = session['metadata']['product_ids'].split(",").map(&:to_i)
    products = Product.where(id: product_ids)

    products.each do |product|
      quantity = 1 # assume 1 for Buy Now; for cart we could store quantity metadata if needed
      OrderItem.create!(
        order: order,
        product: product,
        quantity: quantity,
        unit_price: product.price
      )

      Payment.create!(
        order: order,
        amount: product.price * quantity,
        stripe_payment_id: session['payment_intent'],
        status: 'completed'
      )

      # Create download access
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

