require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  test "unavailable products cannot be added to the cart" do
    product = products(:rose_design)
    product.update!(is_available: false)

    post add_cart_path, params: { product_id: product.id }, headers: @ua

    assert_redirected_to products_path
    assert_equal "This product is not available.", flash[:alert]
  end

  test "cart removes products that became unavailable" do
    product = products(:rose_design)
    post add_cart_path, params: { product_id: product.id }, headers: @ua
    product.update!(is_available: false)

    get cart_path, headers: @ua

    assert_response :success
    assert_includes response.body, "Your cart is empty"
    assert_select ".cart-item", count: 0
  end
end
