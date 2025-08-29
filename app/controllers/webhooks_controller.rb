class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def stripe
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = Rails.application.credentials.stripe[:webhook_secret]
    
    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
    rescue JSON::ParserError => e
      render json: { error: 'Invalid payload' }, status: 400
      return
    rescue Stripe::SignatureVerificationError => e
      render json: { error: 'Invalid signature' }, status: 400
      return
    end
    
    case event['type']
    when 'checkout.session.completed'
      handle_successful_payment(event['data']['object'])
    end
    
    render json: { status: 'success' }
  end
  
  private
  
  def handle_successful_payment(session)
    # Extract metadata from session
    product_id = session['metadata']['product_id']
    user_id = session['metadata']['user_id']
    
    return unless product_id && user_id
    
    product = Product.find_by(id: product_id)
    user = User.find_by(id: user_id)
    
    return unless product && user
    
    # Create order and payment records
    order = Order.create!(
      user: user,
      total: session['amount_total'] / 100.0,
      status: 'completed'
    )
    
    OrderItem.create!(
      order: order,
      product: product,
      quantity: 1,
      unit_price: product.price
    )
    
    Payment.create!(
      order: order,
      amount: session['amount_total'] / 100.0,
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
