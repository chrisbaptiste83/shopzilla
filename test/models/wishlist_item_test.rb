require "test_helper"

class WishlistItemTest < ActiveSupport::TestCase
  test "valid with a user and product" do
    item = WishlistItem.new(user: users(:gloria), product: products(:rose_design))
    assert item.valid?
  end

  test "invalid when user already wishlisted the same product" do
    # alice already has hoop_art via the alice_wishlist fixture
    dup = WishlistItem.new(user: users(:alice), product: products(:hoop_art))
    assert_not dup.valid?
    assert dup.errors[:user_id].any?
  end

  test "different users can wishlist the same product" do
    item = WishlistItem.new(user: users(:gloria), product: products(:hoop_art))
    assert item.valid?
  end

  test "the same user can wishlist different products" do
    item = WishlistItem.new(user: users(:alice), product: products(:rose_design))
    assert item.valid?
  end
end
