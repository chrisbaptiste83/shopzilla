require "test_helper"

class ProductTest < ActiveSupport::TestCase
  def valid_product
    Product.new(title: "Sunflower Design", price: 499, category: categories(:floral))
  end

  test "valid with required attributes" do
    assert valid_product.valid?
  end

  test "invalid without title" do
    product = valid_product
    product.title = nil
    assert_not product.valid?
    assert product.errors[:title].any?
  end

  test "invalid with title shorter than 3 characters" do
    product = valid_product
    product.title = "AB"
    assert_not product.valid?
  end

  test "invalid with title longer than 255 characters" do
    product = valid_product
    product.title = "A" * 256
    assert_not product.valid?
  end

  test "valid with title at minimum length" do
    product = valid_product
    product.title = "ABC"
    assert product.valid?
  end

  test "invalid without price" do
    product = valid_product
    product.price = nil
    assert_not product.valid?
    assert product.errors[:price].any?
  end

  test "invalid with price of zero" do
    product = valid_product
    product.price = 0
    assert_not product.valid?
  end

  test "invalid with negative price" do
    product = valid_product
    product.price = -10
    assert_not product.valid?
  end

  test "invalid without category when new_category_name is blank" do
    product = Product.new(title: "Test Design", price: 100)
    assert_not product.valid?
    assert product.errors[:category_id].any?
  end

  test "valid when new_category_name is provided instead of category_id" do
    product = Product.new(title: "Custom Design", price: 299, new_category_name: "Holiday")
    assert product.valid?
  end

  test "creates category from new_category_name on save" do
    assert_difference "Category.count" do
      product = Product.create!(title: "Holiday Design", price: 299, new_category_name: "Seasonal Specials")
      assert_equal "Seasonal Specials", product.category.name
    end
  end

  test "fixture rose_design is valid" do
    assert products(:rose_design).valid?
  end

  test "fixture hoop_art is valid" do
    assert products(:hoop_art).valid?
  end
end
