require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "checkout session webhook creates one payment per order and respects quantities" do
    digital_product = Product.create!(
      title: "Webhook Digital Design",
      price: 799,
      category: categories(:floral),
      is_available: true,
      physical_product: false,
      shippable: false
    )

    event = {
      "type" => "checkout.session.completed",
      "data" => {
        "object" => {
          "id" => "cs_test_webhook_multi_item",
          "amount_total" => 2497,
          "payment_intent" => "pi_test_webhook_multi_item",
          "metadata" => {
            "user_id" => users(:alice).id.to_s,
            "product_ids" => "#{digital_product.id},#{products(:hoop_art).id}",
            "product_quantities" => {
              digital_product.id.to_s => 2,
              products(:hoop_art).id.to_s => 1
            }.to_json
          }
        }
      }
    }

    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) do |_payload, _sig_header, _endpoint_secret|
      event
    end

    begin
      assert_difference -> { Order.count }, 1 do
        assert_difference -> { Payment.count }, 1 do
          assert_difference -> { OrderItem.count }, 2 do
            post "/webhooks/stripe", params: "{}", headers: webhook_headers
          end
        end
      end
    ensure
      Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event)
    end

    assert_response :success

    order = Order.find_by!(stripe_session_id: "cs_test_webhook_multi_item")
    assert_equal 24.97, order.total.to_f
    assert_equal "completed", order.status
    assert_equal 24.97, order.payment.amount.to_f
    assert_equal "pi_test_webhook_multi_item", order.payment.stripe_payment_id
    assert_equal 2, order.order_items.find_by(product: digital_product).quantity
    assert_equal 1, order.order_items.find_by(product: products(:hoop_art)).quantity
  end

  test "payment_intent succeeded webhook creates order for tap_to_pay terminal payments" do
    event = {
      "type" => "payment_intent.succeeded",
      "data" => {
        "object" => {
          "id" => "pi_test_terminal_tap",
          "amount" => 1299,
          "metadata" => {
            "user_id" => users(:alice).id.to_s,
            "product_ids" => products(:hoop_art).id.to_s,
            "tap_to_pay" => "true"
          }
        }
      }
    }

    payload = event.to_json
    original_construct_event = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) { |p, s, e| JSON.parse(p) }
    begin
      post "/webhooks/stripe", params: payload, headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "test" }
      assert_response :success

      order = Order.find_by!(stripe_session_id: "pi_test_terminal_tap")
      assert_equal 12.99, order.total.to_f
      assert_equal "completed", order.status
      assert_equal 12.99, order.payment.amount.to_f
      assert_equal "pi_test_terminal_tap", order.payment.stripe_payment_id
    ensure
      Stripe::Webhook.define_singleton_method(:construct_event, original_construct_event)
    end
  end

  private

  def webhook_headers
    @ua.merge(
      "CONTENT_TYPE" => "application/json",
      "HTTP_STRIPE_SIGNATURE" => "test-signature"
    )
  end
end
