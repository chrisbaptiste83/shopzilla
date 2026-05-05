require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "success page redirects unauthenticated users to sign in" do
    get pages_success_url, headers: @ua
    assert_redirected_to new_user_session_path
  end

  test "success page returns 200 for authenticated user" do
    sign_in users(:alice)
    get pages_success_url(session_id: orders(:alice_completed).stripe_session_id), headers: @ua
    assert_response :success
  end

  test "success page loads persisted download accesses for the matching order" do
    sign_in users(:alice)

    get pages_success_url(session_id: orders(:alice_completed).stripe_session_id), headers: @ua

    assert_response :success
    assert_includes response.body, products(:rose_design).title
  end

  test "success page does not show downloads for a missing order" do
    sign_in users(:alice)

    get pages_success_url(session_id: "cs_test_missing_order"), headers: @ua

    assert_response :success
    assert_includes response.body, "Your download links will be available shortly"
  end

  test "cancel page is publicly accessible" do
    get pages_cancel_url, headers: @ua
    assert_response :success
  end
end
