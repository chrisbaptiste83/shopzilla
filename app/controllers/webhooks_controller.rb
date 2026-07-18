# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def stripe
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    endpoint_secret = stripe_webhook_secret

    if endpoint_secret.blank?
      Rails.logger.error "Stripe webhook secret missing"
      return render json: { error: "Webhook not configured" }, status: :service_unavailable
    end

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
    rescue JSON::ParserError => e
      Rails.logger.error "Webhook JSON error: #{e.message}"
      return render json: { error: "Invalid payload" }, status: :bad_request
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error "Webhook signature error: #{e.message}"
      return render json: { error: "Invalid signature" }, status: :bad_request
    end

    begin
      case event["type"]
      when "checkout.session.completed"
        handle_successful_payment(event["data"]["object"])
      when "payment_intent.succeeded"
        handle_successful_payment_intent(event["data"]["object"])
      end
    rescue StandardError => e
      # Return non-2xx so Stripe retries instead of silently dropping fulfillment.
      Rails.logger.error "Webhook handler error (#{event['type']}): #{e.class}: #{e.message}"
      return render json: { error: "Handler failed" }, status: :internal_server_error
    end

    render json: { status: "success" }
  end

  private

  def stripe_webhook_secret
    ENV["STRIPE_WEBHOOK_SECRET"].presence ||
      Rails.application.credentials.dig(:stripe, :webhook_secret)
  end

  def handle_successful_payment(session)
    CheckoutCompletionService.complete_from_checkout_session(session)
  end

  def handle_successful_payment_intent(intent)
    CheckoutCompletionService.complete_from_payment_intent(intent)
  end
end
