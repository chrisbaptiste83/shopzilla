# frozen_string_literal: true

module Api
  module V1
    class TerminalController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!

      def connection_token
        token = StripeTerminalService.connection_token
        render json: { secret: token.secret }
      rescue Stripe::StripeError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def create_payment_intent
        intent = StripeTerminalService.create_payment_intent(
          user: current_user,
          amount_cents: terminal_params[:amount_cents],
          product_ids: terminal_params[:product_ids]
        )

        render json: {
          client_secret: intent.client_secret,
          id: intent.id,
          amount_cents: intent.amount
        }
      rescue StripeTerminalService::ValidationError => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue Stripe::StripeError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def capture
        intent = StripeTerminalService.capture!(
          user: current_user,
          payment_intent_id: terminal_params[:payment_intent_id]
        )
        render json: { status: intent.status, id: intent.id }
      rescue StripeTerminalService::ValidationError => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue StripeTerminalService::OwnershipError => e
        render json: { error: e.message }, status: :forbidden
      rescue Stripe::StripeError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def terminal_params
        params.permit(:amount_cents, :payment_intent_id, product_ids: [])
      end
    end
  end
end
