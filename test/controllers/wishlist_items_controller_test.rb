require "test_helper"

class WishlistItemsControllerTest < ActionDispatch::IntegrationTest
  test "index redirects unauthenticated users to sign in" do
    get wishlist_items_path, headers: @ua
    assert_redirected_to new_user_session_path
  end

  test "index returns 200 for authenticated user" do
    sign_in users(:alice)
    get wishlist_items_path, headers: @ua
    assert_response :success
  end

  test "create adds item to wishlist" do
    sign_in users(:gloria)
    assert_difference "WishlistItem.count" do
      post wishlist_items_path, params: { product_id: products(:rose_design).id }, headers: @ua
    end
  end

  test "create requires authentication" do
    assert_no_difference "WishlistItem.count" do
      post wishlist_items_path, params: { product_id: products(:rose_design).id }, headers: @ua
    end
    assert_redirected_to new_user_session_path
  end

  test "destroy removes item from wishlist" do
    sign_in users(:alice)
    assert_difference "WishlistItem.count", -1 do
      delete wishlist_item_path(wishlist_items(:alice_wishlist)), headers: @ua
    end
  end

  test "destroy requires authentication" do
    assert_no_difference "WishlistItem.count" do
      delete wishlist_item_path(wishlist_items(:alice_wishlist)), headers: @ua
    end
    assert_redirected_to new_user_session_path
  end
end
