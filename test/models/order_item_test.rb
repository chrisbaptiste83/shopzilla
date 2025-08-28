require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", password: "password123")
    @product = Product.create!(title: "Test Product", price: 15.00)
    @order = Order.create!(user: @user, total: 30.00, status: "pending", shipping_address: "123 Main St")
    @order_item = OrderItem.new(
      order: @order,
      product: @product,
      quantity: 2,
      unit_price: 15.00
    )
  end

  test "should be valid with valid attributes" do
    assert @order_item.valid?
  end

  test "should require order" do
    @order_item.order = nil
    assert_not @order_item.valid?
    assert_includes @order_item.errors[:order], "must exist"
  end

  test "should require product" do
    @order_item.product = nil
    assert_not @order_item.valid?
    assert_includes @order_item.errors[:product], "must exist"
  end

  test "should require quantity" do
    @order_item.quantity = nil
    assert_not @order_item.valid?
    assert_includes @order_item.errors[:quantity], "can't be blank"
  end

  test "quantity should be greater than zero" do
    @order_item.quantity = 0
    assert_not @order_item.valid?
    assert_includes @order_item.errors[:quantity], "must be greater than 0"
  end

  test "quantity should be an integer" do
    @order_item.quantity = 1.5
    assert_not @order_item.valid?
    assert_includes @order_item.errors[:quantity], "must be an integer"
  end

  test "should require unit_price" do
    # Create order item without product to avoid callback interference
    order_item = OrderItem.new(order: @order, quantity: 1, unit_price: nil)
    assert_not order_item.valid?
    assert_includes order_item.errors[:unit_price], "can't be blank"
  end

  test "unit_price should be greater than zero" do
    # Create order item without product to avoid callback interference
    order_item = OrderItem.new(order: @order, quantity: 1, unit_price: 0)
    assert_not order_item.valid?
    assert_includes order_item.errors[:unit_price], "must be greater than 0"
  end

  test "total_price should calculate quantity times unit_price" do
    @order_item.quantity = 3
    @order_item.unit_price = 10.00
    assert_equal 30.00, @order_item.total_price
  end

  test "formatted_total_price should return formatted price" do
    @order_item.quantity = 2
    @order_item.unit_price = 12.50
    assert_equal "$25.00", @order_item.formatted_total_price
  end

  test "formatted_unit_price should return formatted unit price" do
    @order_item.unit_price = 15.75
    assert_equal "$15.75", @order_item.formatted_unit_price
  end

  test "should set unit_price from product when product changes" do
    new_product = Product.create!(title: "New Product", price: 25.00)
    @order_item.product = new_product
    @order_item.valid? # Trigger validations
    assert_equal 25.00, @order_item.unit_price
  end

  test "should not change unit_price when product doesn't change" do
    original_price = @order_item.unit_price
    @order_item.quantity = 5 # Change something else
    @order_item.valid? # Trigger validations
    assert_equal original_price, @order_item.unit_price
  end
end
