require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  test "customer_receipt sends receipt to the purchasing user" do
    order = orders(:alice_completed)

    email = OrderMailer.customer_receipt(order.id)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ order.user.email ], email.to
    assert_includes email.subject, "Order ##{order.id}"
    assert_includes email.html_part.body.to_s, "$5.99"
  end

  test "merchant_order_notification notifies store owner of sale" do
    order = orders(:alice_completed)

    email = OrderMailer.merchant_order_notification(order.id)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "support@gloriasembroideryshop.com" ], email.to
    assert_includes email.subject, "Sale"
    assert_includes email.subject, "Order ##{order.id}"
    assert_includes email.html_part.body.to_s, order.user.email
  end
end
