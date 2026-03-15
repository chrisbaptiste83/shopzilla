require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  test "valid with order, product, quantity, and unit_price" do
    item = OrderItem.new(
      order: orders(:alice_pending),
      product: products(:rose_design),
      quantity: 1,
      unit_price: 5.99
    )
    assert item.valid?
  end

  test "belongs to an order" do
    assert_respond_to order_items(:rose_item), :order
  end

  test "belongs to a product" do
    assert_respond_to order_items(:rose_item), :product
  end

  test "fixture rose_item references correct order and product" do
    item = order_items(:rose_item)
    assert_equal orders(:alice_completed), item.order
    assert_equal products(:rose_design), item.product
  end
end
