require "test_helper"

class CheckoutControllerTest < ActionDispatch::IntegrationTest
  test "create redirects unauthenticated users to sign in" do
    post checkout_path, params: { product_id: products(:rose_design).id }, headers: @ua
    assert_redirected_to new_user_session_path
  end

  test "direct digital product checkout creates a stripe session" do
    sign_in users(:alice)

    original_create = Stripe::Checkout::Session.method(:create)
    created_payload = nil
    Stripe::Checkout::Session.define_singleton_method(:create) do |payload|
      created_payload = payload
      Struct.new(:url).new("https://checkout.stripe.test/session")
    end

    post checkout_path(product_id: products(:rose_design).id), headers: @ua

    assert_redirected_to "https://checkout.stripe.test/session"
    assert_equal 1, created_payload[:line_items].first[:quantity]
    assert_equal products(:rose_design).id.to_s, JSON.parse(created_payload[:metadata][:product_quantities]).keys.first
  ensure
    Stripe::Checkout::Session.define_singleton_method(:create, original_create) if original_create
  end
end
