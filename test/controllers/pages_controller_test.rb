require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "success page redirects unauthenticated users to sign in" do
    get pages_success_url, headers: @ua
    assert_redirected_to new_user_session_path
  end

  test "success page returns 200 for authenticated user" do
    sign_in users(:alice)
    get pages_success_url, headers: @ua
    assert_response :success
  end

  test "cancel page is publicly accessible" do
    get pages_cancel_url, headers: @ua
    assert_response :success
  end
end
