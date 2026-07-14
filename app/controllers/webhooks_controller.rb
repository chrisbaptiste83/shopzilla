class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def stripe
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    endpoint_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
    rescue JSON::ParserError => e
      Rails.logger.error "Webhook JSON error: #{e.message}"
      return render json: { error: "Invalid payload" }, status: 400
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "Webhook signature error: #{e.message}"
      return render json: { error: "Invalid signature" }, status: 400
    end

    case event["type"]
    when "checkout.session.completed"
      handle_successful_payment(event["data"]["object"])
    when "payment_intent.succeeded"
      handle_successful_payment_intent(event["data"]["object"])
    end

    render json: { status: "success" }
  end

  private

  def handle_successful_payment(session)
    CheckoutCompletionService.complete_from_checkout_session(session)
  end

  def handle_successful_payment_intent(intent)
    CheckoutCompletionService.complete_from_payment_intent(intent)
  end
end
