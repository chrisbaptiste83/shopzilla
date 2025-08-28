require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  def setup
    @category = Category.new(name: "Floral Designs")
  end

  test "should be valid with valid attributes" do
    assert @category.valid?
  end

  test "should require name" do
    @category.name = nil
    assert_not @category.valid?
    assert_includes @category.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    @category.save!
    duplicate_category = Category.new(name: "Floral Designs")
    assert_not duplicate_category.valid?
    assert_includes duplicate_category.errors[:name], "has already been taken"
  end

  test "name should have minimum length" do
    @category.name = "a"
    assert_not @category.valid?
    assert_includes @category.errors[:name], "is too short (minimum is 2 characters)"
  end

  test "name should have maximum length" do
    @category.name = "a" * 51
    assert_not @category.valid?
    assert_includes @category.errors[:name], "is too long (maximum is 50 characters)"
  end

  test "with_products scope should return categories with products" do
    category_with_products = Category.create!(name: "With Products")
    category_without_products = Category.create!(name: "Without Products")

    Product.create!(title: "Test Product", price: 10, category: category_with_products.name)

    categories_with_products = Category.with_products
    assert_includes categories_with_products, category_with_products
    assert_not_includes categories_with_products, category_without_products
  end

  test "alphabetical scope should order by name" do
    # Clear existing categories to avoid fixture interference
    Category.delete_all

    zebra_category = Category.create!(name: "Zebra")
    alpha_category = Category.create!(name: "Alpha")
    beta_category = Category.create!(name: "Beta")

    alphabetical_categories = Category.alphabetical
    assert_equal alpha_category, alphabetical_categories.first
    assert_equal beta_category, alphabetical_categories.second
    assert_equal zebra_category, alphabetical_categories.last
  end

  test "products_count should return number of products" do
    @category.save!
    assert_equal 0, @category.products_count

    Product.create!(title: "Product 1", price: 10, category: @category.name)
    Product.create!(title: "Product 2", price: 15, category: @category.name)

    assert_equal 2, @category.products_count
  end

  test "display_name should return titleized name" do
    @category.name = "floral designs"
    assert_equal "Floral Designs", @category.display_name
  end

  test "products method should return products with matching category" do
    @category.save!
    product1 = Product.create!(title: "Test Product 1", price: 10, category: @category.name)
    product2 = Product.create!(title: "Test Product 2", price: 15, category: "Other Category")

    category_products = @category.products
    assert_includes category_products, product1
    assert_not_includes category_products, product2
  end
end
