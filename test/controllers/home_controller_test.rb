require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "homepage renders with image-backed products" do
    products(:rose_design).images.attach(
      io: StringIO.new("image-binary"),
      filename: "preview.png",
      content_type: "image/png"
    )

    get root_url, headers: @ua

    assert_response :success
  end
end
