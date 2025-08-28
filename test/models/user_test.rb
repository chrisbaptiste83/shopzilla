require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "should be valid with valid attributes" do
    assert @user.valid?
  end

  test "should require email" do
    @user.email = nil
    assert_not @user.valid?
    assert_includes @user.errors[:email], "can't be blank"
  end

  test "should require unique email" do
    @user.save!
    duplicate_user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email], "has already been taken"
  end

  test "should require valid email format" do
    @user.email = "invalid_email"
    assert_not @user.valid?
    assert_includes @user.errors[:email], "is invalid"
  end

  test "should require password" do
    @user.password = nil
    @user.password_confirmation = nil
    assert_not @user.valid?
    assert_includes @user.errors[:password], "can't be blank"
  end

  test "full_name should return humanized email prefix" do
    @user.email = "john.doe@example.com"
    assert_equal "John doe", @user.full_name
  end

  test "total_orders should return order count" do
    @user.save!
    assert_equal 0, @user.total_orders

    # Create orders for the user
    order1 = Order.create!(user: @user, total: 25.00, status: "pending", shipping_address: "123 Main St")
    order2 = Order.create!(user: @user, total: 35.00, status: "paid", shipping_address: "123 Main St")

    assert_equal 2, @user.total_orders
  end

  test "total_spent should calculate total from order items" do
    @user.save!
    product = Product.create!(title: "Test Product", price: 10)

    order = Order.create!(user: @user, total: 30.00, status: "paid", shipping_address: "123 Main St")
    OrderItem.create!(order: order, product: product, quantity: 2, unit_price: 10.00)
    OrderItem.create!(order: order, product: product, quantity: 1, unit_price: 10.00)

    assert_equal 30.00, @user.total_spent
  end

  test "should destroy dependent orders when user is destroyed" do
    @user.save!
    order = Order.create!(user: @user, total: 25.00, status: "pending", shipping_address: "123 Main St")

    assert_difference "Order.count", -1 do
      @user.destroy
    end
  end
end
