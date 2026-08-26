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
    assert_select ".sz-hero img.sz-hero-media[src*='categories/studio']", count: 1
    assert_select ".sz-product-image img[src^='https://ik.imagekit.io/mlvnqaq3b/'][src*='c-at_max']", minimum: 1
    assert_select ".sz-product-image img[src*='r-max']", count: 0
    assert_select ".sz-product-image img[src*='/rails/active_storage/representations/']", count: 0
    assert_select "link[href*='cdn.jsdelivr.net']", count: 0
    assert_select "script[src*='js.stripe.com']", count: 0
  end
end
