require "test_helper"

class CheckoutControllerTest < ActionDispatch::IntegrationTest
  test "create redirects unauthenticated users to sign in" do
    post checkout_path, params: { product_id: products(:rose_design).id }, headers: @ua
    assert_redirected_to new_user_session_path
  end
end
