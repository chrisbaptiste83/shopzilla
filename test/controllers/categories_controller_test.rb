require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  test "show renders a category page" do
    get category_path(categories(:floral)), headers: @ua

    assert_response :success
    assert_includes response.body, categories(:floral).name
  end
end
