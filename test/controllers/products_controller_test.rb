require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  # --- Public actions ---

  test "index is publicly accessible" do
    get products_path, headers: @ua
    assert_response :success
  end

  test "index filters by category" do
    get products_path, params: { category_id: categories(:floral).id }, headers: @ua
    assert_response :success
  end

  test "index searches by keyword" do
    get products_path, params: { search: "Rose" }, headers: @ua
    assert_response :success
  end

  test "index sorts by price" do
    get products_path, params: { sort: "price_low" }, headers: @ua
    assert_response :success
  end

  test "show is publicly accessible" do
    get product_path(products(:rose_design)), headers: @ua
    assert_response :success
  end

  # --- Admin-only: new ---

  test "new redirects unauthenticated users to sign in" do
    get new_product_path, headers: @ua
    assert_redirected_to new_user_session_path
  end

  test "new redirects non-admin to root with alert" do
    sign_in users(:alice)
    get new_product_path, headers: @ua
    assert_redirected_to root_path
  end

  test "new redirects admin to ActiveAdmin product form" do
    sign_in users(:gloria)
    get new_product_path, headers: @ua
    assert_redirected_to new_admin_product_path
  end

  # --- Admin-only: destroy ---

  test "destroy requires authentication" do
    assert_no_difference "Product.count" do
      delete product_path(products(:rose_design)), headers: @ua
    end
    assert_redirected_to new_user_session_path
  end

  test "destroy requires admin role" do
    sign_in users(:alice)
    assert_no_difference "Product.count" do
      delete product_path(products(:rose_design)), headers: @ua
    end
    assert_redirected_to root_path
  end

  test "destroy succeeds for admin" do
    sign_in users(:gloria)
    assert_difference "Product.count", -1 do
      delete product_path(products(:hoop_art)), headers: @ua
    end
    assert_redirected_to products_url
  end
end
