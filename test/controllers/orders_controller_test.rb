require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  test "index redirects unauthenticated users to sign in" do
    get orders_path, headers: @ua
    assert_redirected_to new_user_session_path
  end

  test "index returns 200 for authenticated user" do
    sign_in users(:alice)
    get orders_path, headers: @ua
    assert_response :success
  end

  test "show returns 200 for the order owner" do
    sign_in users(:alice)
    get order_path(orders(:alice_completed)), headers: @ua
    assert_response :success
  end

  test "show redirects unauthenticated users to sign in" do
    get order_path(orders(:alice_completed)), headers: @ua
    assert_redirected_to new_user_session_path
  end
end
