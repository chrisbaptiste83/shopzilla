require "test_helper"

class CheckoutCompletionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @product = products(:rose_design)
  end

  test "complete_from_checkout_session creates order, payment, order items, and download access" do
    session = {
      "id" => "cs_test_service_123",
      "payment_intent" => "pi_test_service_123",
      "amount_total" => 1500,
      "metadata" => {
        "user_id" => @user.id.to_s,
        "product_ids" => @product.id.to_s
      }
    }

    assert_difference ["Order.count", "Payment.count", "OrderItem.count", "DownloadAccess.count"], 1 do
      order = CheckoutCompletionService.complete_from_checkout_session(session)
      assert_equal "completed", order.status
      assert_equal 15.0, order.total
      assert_equal "cs_test_service_123", order.stripe_session_id
    end
  end

  test "complete_from_checkout_session is idempotent" do
    session = {
      "id" => "cs_test_service_idempotent",
      "payment_intent" => "pi_test_service_idempotent",
      "amount_total" => 1500,
      "metadata" => {
        "user_id" => @user.id.to_s,
        "product_ids" => @product.id.to_s
      }
    }

    CheckoutCompletionService.complete_from_checkout_session(session)
    assert_no_difference ["Order.count", "Payment.count", "OrderItem.count"] do
      CheckoutCompletionService.complete_from_checkout_session(session)
    end
  end

  test "complete_from_payment_intent creates order for terminal tap to pay" do
    intent = {
      "id" => "pi_terminal_test_123",
      "amount" => 2500,
      "metadata" => {
        "user_id" => @user.id.to_s,
        "product_ids" => @product.id.to_s,
        "tap_to_pay" => "true"
      }
    }

    assert_difference ["Order.count", "Payment.count", "OrderItem.count", "DownloadAccess.count"], 1 do
      order = CheckoutCompletionService.complete_from_payment_intent(intent)
      assert_equal "completed", order.status
      assert_equal 25.0, order.total
    end
  end
end
