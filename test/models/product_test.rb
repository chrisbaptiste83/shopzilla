require "test_helper"

class ProductTest < ActiveSupport::TestCase
  def setup
    @product = Product.new(
      title: "Beautiful Floral Design",
      price: 15,
      description: "A lovely embroidery design",
      category: "Floral",
      is_available: true
    )
  end

  test "should be valid with valid attributes" do
    assert @product.valid?
  end

  test "should require title" do
    @product.title = nil
    assert_not @product.valid?
    assert_includes @product.errors[:title], "can't be blank"
  end

  test "should require price" do
    @product.price = nil
    assert_not @product.valid?
    assert_includes @product.errors[:price], "can't be blank"
  end

  test "price should be greater than zero" do
    @product.price = 0
    assert_not @product.valid?
    assert_includes @product.errors[:price], "must be greater than 0"
  end

  test "price should be numeric" do
    @product.price = "not_a_number"
    assert_not @product.valid?
    assert_includes @product.errors[:price], "is not a number"
  end

  test "title should have minimum length" do
    @product.title = "ab"
    assert_not @product.valid?
    assert_includes @product.errors[:title], "is too short (minimum is 3 characters)"
  end

  test "title should have maximum length" do
    @product.title = "a" * 101
    assert_not @product.valid?
    assert_includes @product.errors[:title], "is too long (maximum is 100 characters)"
  end

  test "category should have maximum length" do
    @product.category = "a" * 51
    assert_not @product.valid?
    assert_includes @product.errors[:category], "is too long (maximum is 50 characters)"
  end

  test "file_format should have maximum length" do
    @product.file_format = "a" * 21
    assert_not @product.valid?
    assert_includes @product.errors[:file_format], "is too long (maximum is 20 characters)"
  end

  test "dimensions should have maximum length" do
    @product.dimensions = "a" * 51
    assert_not @product.valid?
    assert_includes @product.errors[:dimensions], "is too long (maximum is 50 characters)"
  end

  test "available scope should return only available products" do
    available_product = Product.create!(title: "Available", price: 10, is_available: true)
    unavailable_product = Product.create!(title: "Unavailable", price: 10, is_available: false)

    assert_includes Product.available, available_product
    assert_not_includes Product.available, unavailable_product
  end

  test "by_category scope should filter by category" do
    floral_product = Product.create!(title: "Floral", price: 10, category: "Floral")
    animal_product = Product.create!(title: "Animal", price: 10, category: "Animal")

    floral_results = Product.by_category("Floral")
    assert_includes floral_results, floral_product
    assert_not_includes floral_results, animal_product
  end

  test "by_category scope should return all when category is blank" do
    product1 = Product.create!(title: "Product 1", price: 10, category: "Floral")
    product2 = Product.create!(title: "Product 2", price: 10, category: "Animal")

    all_results = Product.by_category("")
    assert_includes all_results, product1
    assert_includes all_results, product2
  end

  test "formatted_price should return price with dollar sign" do
    @product.price = 25
    assert_equal "$25", @product.formatted_price
  end

  test "display_category should return titleized category" do
    @product.category = "floral designs"
    assert_equal "Floral Designs", @product.display_category
  end

  test "display_category should return Uncategorized when category is blank" do
    @product.category = ""
    assert_equal "Uncategorized", @product.display_category

    @product.category = nil
    assert_equal "Uncategorized", @product.display_category
  end
end
