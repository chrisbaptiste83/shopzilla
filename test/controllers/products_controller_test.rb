require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  # --- Public actions ---

  test "index is publicly accessible" do
    get products_path, headers: @ua
    assert_response :success
  end

  test "index exposes accessible navigation landmarks and active state" do
    get products_path, headers: @ua

    assert_response :success
    assert_select "a.skip-link[href='#main-content']", text: "Skip to main content"
    assert_select "main#main-content[tabindex='-1']", count: 1
    assert_select ".navbar-center a.nav-link-active[aria-current='page']", text: "All designs"
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
  end

  test "show is publicly accessible" do
    get product_path(products(:rose_design)), headers: @ua
    assert_response :success
  end

  test "show marks one gallery thumbnail as selected" do
    product = products(:rose_design)
    product.images.attach(
      io: StringIO.new("primary-image"),
      filename: "primary.png",
      content_type: "image/png"
    )
    product.images.attach(
      io: StringIO.new("alternate-image"),
      filename: "alternate.png",
      content_type: "image/png"
    )

    get product_path(product), headers: @ua

    assert_response :success
    assert_select ".product-gallery-thumbnail", count: 2
    assert_select ".product-gallery-thumbnail[aria-current='true']", count: 1
    assert_select ".product-detail-media[src*='c-at_max'][src*='v=']", count: 1
    assert_select ".product-detail-media[src*='r-max']", count: 0
  end

  test "digital product show communicates instant delivery" do
    sign_in users(:alice)

    get product_path(products(:rose_design)), headers: @ua

    assert_response :success
    assert_select ".product-type-label", text: /Digital download/
    assert_select ".product-detail-specs dd", text: "Immediately after checkout"
    assert_select "button", text: "Buy now - instant download"
  end

  test "physical product show communicates shipping instead of download" do
    sign_in users(:alice)

    get product_path(products(:hoop_art)), headers: @ua

    assert_response :success
    assert_select "meta[name='description'][content*='Physical embroidery product.']", count: 1
    assert_select ".product-type-label", text: /Physical item/
    assert_select ".product-detail-specs dd", text: "Shipping calculated at checkout"
    assert_select "button", text: "Buy now - secure checkout"
    assert_select "button", text: "Buy now - instant download", count: 0
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
