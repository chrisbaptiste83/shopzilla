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

  test "index only displays available products" do
    products(:rose_design).update!(is_available: false)

    get products_path, headers: @ua

    assert_response :success
    assert_not_includes response.body, products(:rose_design).title
    assert_includes response.body, products(:hoop_art).title
  end

  test "index provides a file format filter" do
    get products_path, headers: @ua

    assert_response :success
    assert_select "select[name='file_format'] option[value='DST']", text: "DST"
  end

  test "index serves complete product grid images through versioned ImageKit previews" do
    products(:rose_design).images.attach(
      io: StringIO.new("image-binary"),
      filename: "preview.png",
      content_type: "image/png"
    )

    get products_path, headers: @ua

    assert_response :success
    assert_select ".catalog-product-media img[src^='https://ik.imagekit.io/mlvnqaq3b/'][src*='w-420,h-420,c-at_max,f-auto,q-72,e-sharpen-20'][src*='v=']",
      minimum: 1
    assert_select ".catalog-product-media img[src*='r-max']", count: 0
    assert_select ".catalog-product-media img[src*='/rails/active_storage/representations/']", count: 0
    assert_select ".catalog-product-media .catalog-product-category", count: 0
    assert_select ".catalog-product-copy > .catalog-product-category", minimum: 1
  end

  test "show is publicly accessible" do
    get product_path(products(:rose_design)), headers: @ua
    assert_response :success
  end

  test "show uses the complete light preview without a circular crop" do
    product = products(:rose_design)
    product.images.attach(
      io: StringIO.new("detail-image"),
      filename: "rose-detail.png",
      content_type: "image/png",
      metadata: { "image_role" => "primary", "render_style" => "detail" }
    )
    product.images.attach(
      io: StringIO.new("light-image"),
      filename: "rose-light.png",
      content_type: "image/png",
      metadata: { "image_role" => "alternate", "render_style" => "light" }
    )
    light_image = product.reload.image_for_style("light")

    get product_path(product), headers: @ua

    assert_response :success
    assert_select ".product-gallery-thumbnail", count: 2
    assert_select ".product-detail-media[src*='#{light_image.blob.key}'][src*='c-at_max'][src*='v=']", count: 1
    assert_select ".product-detail-media[src*='r-max']", count: 0
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
