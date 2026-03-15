require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "valid with a name" do
    category = Category.new(name: "Wildlife Scenes")
    assert category.valid?
  end

  test "fixture floral is valid" do
    assert categories(:floral).valid?
  end

  test "fixture geometric is valid" do
    assert categories(:geometric).valid?
  end

  test "has many products" do
    assert_respond_to categories(:floral), :products
  end

  test "associates products correctly" do
    assert_includes categories(:floral).products, products(:rose_design)
  end
end
