require "test_helper"

class OrderTest < ActiveSupport::TestCase
  def valid_order
    Order.new(user: users(:alice), total: 9.99, status: "pending")
  end

  test "valid with required attributes" do
    assert valid_order.valid?
  end

  test "invalid without user" do
    order = valid_order
    order.user = nil
    assert_not order.valid?
    assert order.errors[:user_id].any?
  end

  test "invalid without total" do
    order = valid_order
    order.total = nil
    assert_not order.valid?
    assert order.errors[:total].any?
  end

  test "invalid with negative total" do
    order = valid_order
    order.total = -0.01
    assert_not order.valid?
  end

  test "valid with total of zero" do
    order = valid_order
    order.total = 0
    assert order.valid?
  end

  test "invalid without status" do
    order = valid_order
    order.status = nil
    assert_not order.valid?
    assert order.errors[:status].any?
  end

  test "invalid with unrecognized status" do
    order = valid_order
    order.status = "shipped"
    assert_not order.valid?
    assert order.errors[:status].any?
  end

  test "valid for each allowed status" do
    %w[pending completed failed cancelled].each do |status|
      order = valid_order
      order.status = status
      assert order.valid?, "Expected status '#{status}' to be valid"
    end
  end

  test "stripe_session_id must be unique" do
    dup = Order.new(
      user: users(:gloria),
      total: 1.00,
      status: "pending",
      stripe_session_id: orders(:alice_completed).stripe_session_id
    )
    assert_not dup.valid?
    assert dup.errors[:stripe_session_id].any?
  end

  test "multiple orders may have nil stripe_session_id" do
    Order.create!(user: users(:alice), total: 1.00, status: "pending", stripe_session_id: nil)
    o2 = Order.new(user: users(:gloria), total: 2.00, status: "pending", stripe_session_id: nil)
    assert o2.valid?
  end

  test "has many order_items" do
    assert_respond_to orders(:alice_completed), :order_items
  end

  test "has one payment" do
    assert_respond_to orders(:alice_completed), :payment
  end
end
