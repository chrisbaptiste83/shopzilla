# frozen_string_literal: true

module Api
  module V1
    class TerminalController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!

      # POST /api/v1/terminal/connection_token
      def connection_token
        token = Stripe::Terminal::ConnectionToken.create
        render json: { secret: token.secret }
      rescue Stripe::StripeError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/v1/terminal/payment_intents
      def create_payment_intent
        amount_cents = (params.require(:amount).to_f * 100).to_i
        product_ids  = params[:product_ids] || []

        intent = Stripe::PaymentIntent.create(
          amount: amount_cents,
          currency: "usd",
          payment_method_types: [ "card_present" ],
          capture_method: "manual",
          metadata: {
            user_id: current_user.id,
            product_ids: Array(product_ids).join(","),
            tap_to_pay: "true"
          }
        )

        render json: {
          client_secret: intent.client_secret,
          id: intent.id
        }
      rescue Stripe::StripeError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/v1/terminal/capture
      def capture
        intent_id = params.require(:payment_intent_id)
        intent = Stripe::PaymentIntent.capture(intent_id)

        render json: { status: intent.status, id: intent.id }
      rescue Stripe::StripeError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
