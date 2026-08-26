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

  test "create rejects an unavailable product" do
    sign_in users(:alice)
    products(:rose_design).update!(is_available: false)

    post checkout_path(product_id: products(:rose_design).id), headers: @ua

    assert_redirected_to products_path
    assert_equal "This product is not available.", flash[:alert]
  end

  test "physical product quantities survive the shipping step" do
    sign_in users(:alice)
    product = products(:hoop_art)
    2.times { post add_cart_path, params: { product_id: product.id }, headers: @ua }

    post checkout_path, headers: @ua

    assert_response :success
    quantities_input = css_select("input[name='product_quantities']").first
    assert_equal({ product.id.to_s => 2 }, JSON.parse(quantities_input["value"]))

    original_create = Stripe::Checkout::Session.method(:create)
    created_payload = nil
    Stripe::Checkout::Session.define_singleton_method(:create) do |payload|
      created_payload = payload
      Struct.new(:url).new("https://checkout.stripe.test/session")
    end

    post process_shipping_address_path, params: {
      product_quantities: { product.id.to_s => 2 }.to_json,
      order: {
        shipping_address_attributes: {
          full_name: "Alice Example",
          street_address: "123 Main Street",
          city: "Phoenix",
          state: "AZ",
          zip_code: "85001",
          country: "United States"
        }
      }
    }, headers: @ua

    assert_redirected_to "https://checkout.stripe.test/session"
    assert_equal 2, created_payload[:line_items].first[:quantity]
    assert_equal({ product.id.to_s => 2 }, JSON.parse(created_payload[:metadata][:product_quantities]))
  ensure
    Stripe::Checkout::Session.define_singleton_method(:create, original_create) if original_create
  end
end
