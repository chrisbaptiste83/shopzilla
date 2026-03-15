require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "show redirects unauthenticated users to sign in" do
    get profile_path, headers: @ua
    assert_redirected_to new_user_session_path
  end

  test "show returns 200 for authenticated user" do
    sign_in users(:alice)
    get profile_path, headers: @ua
    assert_response :success
  end

  test "edit redirects unauthenticated users to sign in" do
    get edit_profile_path, headers: @ua
    assert_redirected_to new_user_session_path
  end

  test "edit returns 200 for authenticated user" do
    sign_in users(:alice)
    get edit_profile_path, headers: @ua
    assert_response :success
  end

  test "update requires authentication" do
    patch profile_path, params: { user: { bio: "Updated bio" } }, headers: @ua
    assert_redirected_to new_user_session_path
  end
end
