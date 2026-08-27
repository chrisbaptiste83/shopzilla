require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid with email and password" do
    user = User.new(email: "new@example.com", password: "securepass123", password_confirmation: "securepass123")
    assert user.valid?
  end

  test "invalid without email" do
    user = User.new(password: "securepass123", password_confirmation: "securepass123")
    assert_not user.valid?
    assert user.errors[:email].any?
  end

  test "invalid without password" do
    user = User.new(email: "test@example.com")
    assert_not user.valid?
    assert user.errors[:password].any?
  end

  test "invalid with duplicate email" do
    dup = User.new(email: users(:alice).email, password: "password12345", password_confirmation: "password12345")
    assert_not dup.valid?
    assert dup.errors[:email].any?
  end

  test "admin defaults to false for new records" do
    user = User.create!(email: "brand_new@example.com", password: "password12345", password_confirmation: "password12345")
    assert_not user.admin?
  end

  test "alice fixture is not an admin" do
    assert_not users(:alice).admin?
  end

  test "gloria fixture is an admin" do
    assert users(:gloria).admin?
  end

  test "has many orders" do
    assert_respond_to users(:alice), :orders
  end

  test "has many wishlist_items" do
    assert_respond_to users(:alice), :wishlist_items
  end

  test "has many download_accesses" do
    assert_respond_to users(:alice), :download_accesses
  end

  test "has many wishlist_products through wishlist_items" do
    assert_respond_to users(:alice), :wishlist_products
  end
end
