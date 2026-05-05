require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "checkout session webhook creates one payment per order and respects quantities" do
    event = {
      "type" => "checkout.session.completed",
      "data" => {
        "object" => {
          "id" => "cs_test_webhook_multi_item",
          "amount_total" => 2497,
          "payment_intent" => "pi_test_webhook_multi_item",
          "metadata" => {
            "user_id" => users(:alice).id.to_s,
            "product_ids" => "#{products(:rose_design).id},#{products(:hoop_art).id}",
            "product_quantities" => {
              products(:rose_design).id.to_s => 2,
              products(:hoop_art).id.to_s => 1
            }.to_json
          }
        }
      }
    }

    Stripe::Webhook.singleton_class.stub(:construct_event, event) do
      assert_difference -> { Order.count }, 1 do
        assert_difference -> { Payment.count }, 1 do
          assert_difference -> { OrderItem.count }, 2 do
            assert_difference -> { DownloadAccess.count }, 1 do
              post "/webhooks/stripe", params: "{}", headers: webhook_headers
            end
          end
        end
      end
    end

    assert_response :success

    order = Order.find_by!(stripe_session_id: "cs_test_webhook_multi_item")
    assert_equal 24.97, order.total.to_f
    assert_equal "completed", order.status
    assert_equal 24.97, order.payment.amount.to_f
    assert_equal "pi_test_webhook_multi_item", order.payment.stripe_payment_id
    assert_equal 2, order.order_items.find_by(product: products(:rose_design)).quantity
    assert_equal 1, order.order_items.find_by(product: products(:hoop_art)).quantity
    assert_equal [ products(:rose_design).id ], order.download_accesses.pluck(:product_id)
  end

  private

  def webhook_headers
    @ua.merge(
      "CONTENT_TYPE" => "application/json",
      "HTTP_STRIPE_SIGNATURE" => "test-signature"
    )
  end
end
