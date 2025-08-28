require "test_helper"

class OrderTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", password: "password123")
    @order = Order.new(
      user: @user,
      total: 25.50,
      status: 'pending',
      shipping_address: '123 Main St, City, State 12345'
    )
  end

  test "should be valid with valid attributes" do
    assert @order.valid?
  end

  test "should require user" do
    @order.user = nil
    assert_not @order.valid?
    assert_includes @order.errors[:user], "must exist"
  end

  test "should require total" do
    @order.total = nil
    assert_not @order.valid?
    assert_includes @order.errors[:total], "can't be blank"
  end

  test "total should be greater than zero" do
    @order.total = 0
    assert_not @order.valid?
    assert_includes @order.errors[:total], "must be greater than 0"
  end

  test "should require status" do
    @order.status = nil
    assert_not @order.valid?
    assert_includes @order.errors[:status], "can't be blank"
  end

  test "status should be valid" do
    valid_statuses = %w[pending paid shipped completed cancelled]
    valid_statuses.each do |status|
      @order.status = status
      assert @order.valid?, "#{status} should be valid"
    end
    
    @order.status = "invalid_status"
    assert_not @order.valid?
    assert_includes @order.errors[:status], "is not included in the list"
  end

  test "should require shipping_address" do
    @order.shipping_address = nil
    assert_not @order.valid?
    assert_includes @order.errors[:shipping_address], "can't be blank"
  end

  test "by_status scope should filter by status" do
    pending_order = Order.create!(user: @user, total: 25.00, status: 'pending', shipping_address: '123 Main St')
    paid_order = Order.create!(user: @user, total: 35.00, status: 'paid', shipping_address: '123 Main St')
    
    pending_results = Order.by_status('pending')
    assert_includes pending_results, pending_order
    assert_not_includes pending_results, paid_order
  end

  test "recent scope should order by created_at desc" do
    old_order = Order.create!(user: @user, total: 25.00, status: 'pending', shipping_address: '123 Main St')
    sleep(0.01) # Ensure different timestamps
    new_order = Order.create!(user: @user, total: 35.00, status: 'paid', shipping_address: '456 Oak Ave')
    
    recent_orders = Order.recent
    assert_equal new_order, recent_orders.first
    assert_equal old_order, recent_orders.second
  end

  test "calculate_total should sum order items" do
    @order.save!
    product1 = Product.create!(title: "Test Product 1", price: 10.00)
    product2 = Product.create!(title: "Test Product 2", price: 15.00)
    
    OrderItem.create!(order: @order, product: product1, quantity: 2, unit_price: 10.00)
    OrderItem.create!(order: @order, product: product2, quantity: 1, unit_price: 15.00)
    
    @order.reload
    total = @order.calculate_total
    assert_equal 35.00, total
    assert_equal 35.00, @order.total
  end

  test "formatted_total should return formatted price" do
    @order.total = 25.50
    assert_equal "$25.50", @order.formatted_total
  end

  test "status_badge_class should return correct CSS class" do
    assert_equal 'badge-warning', @order.status_badge_class # pending
    
    @order.status = 'paid'
    assert_equal 'badge-info', @order.status_badge_class
    
    @order.status = 'shipped'
    assert_equal 'badge-primary', @order.status_badge_class
    
    @order.status = 'completed'
    assert_equal 'badge-success', @order.status_badge_class
    
    @order.status = 'cancelled'
    assert_equal 'badge-error', @order.status_badge_class
  end

  test "should destroy dependent order_items when order is destroyed" do
    @order.save!
    product = Product.create!(title: "Test Product", price: 10)
    order_item = OrderItem.create!(order: @order, product: product, quantity: 1, unit_price: 10.00)
    
    assert_difference 'OrderItem.count', -1 do
      @order.reload.destroy
    end
  end
end
