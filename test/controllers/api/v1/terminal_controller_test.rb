require "test_helper"

module Api
  module V1
    class TerminalControllerTest < ActionDispatch::IntegrationTest
      include Devise::Test::IntegrationHelpers

      setup do
        @user = users(:alice)
      end

      test "requires authentication for connection_token" do
        post api_v1_terminal_connection_token_url, as: :json
        assert_response :unauthorized
      end

      test "creates connection_token for authenticated user" do
        sign_in @user

        fake_token = Object.new
        def fake_token.secret; "pst_test_secret_token_123"; end

        Stripe::Terminal::ConnectionToken.define_singleton_method(:create) { fake_token }
        begin
          post api_v1_terminal_connection_token_url, as: :json
          assert_response :success
          json = JSON.parse(response.body)
          assert_equal "pst_test_secret_token_123", json["secret"]
        ensure
          Stripe::Terminal::ConnectionToken.singleton_class.remove_method(:create) if Stripe::Terminal::ConnectionToken.methods(false).include?(:create)
        end
      end

      test "creates payment intent for terminal tap to pay" do
        sign_in @user

        fake_intent = Object.new
        def fake_intent.client_secret; "pi_123_secret_456"; end
        def fake_intent.id; "pi_123"; end
        def fake_intent.amount; 2550; end

        Stripe::PaymentIntent.define_singleton_method(:create) { |*args| fake_intent }
        begin
          post api_v1_terminal_payment_intents_url,
               params: { amount_cents: 2550, product_ids: [ 1, 2 ] },
               as: :json
          assert_response :success
          json = JSON.parse(response.body)
          assert_equal "pi_123_secret_456", json["client_secret"]
          assert_equal "pi_123", json["id"]
          assert_equal 2550, json["amount_cents"]
        ensure
          Stripe::PaymentIntent.singleton_class.remove_method(:create) if Stripe::PaymentIntent.methods(false).include?(:create)
        end
      end

    end
  end
end
