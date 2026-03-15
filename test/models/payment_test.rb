require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  def valid_payment
    Payment.new(
      order: orders(:alice_pending),
      amount: 12.99,
      stripe_payment_id: "pi_test_#{SecureRandom.hex(6)}",
      status: "pending"
    )
  end

  test "valid with required attributes" do
    assert valid_payment.valid?
  end

  test "invalid without order" do
    payment = valid_payment
    payment.order = nil
    assert_not payment.valid?
    assert payment.errors[:order_id].any?
  end

  test "invalid without amount" do
    payment = valid_payment
    payment.amount = nil
    assert_not payment.valid?
    assert payment.errors[:amount].any?
  end

  test "invalid with amount of zero" do
    payment = valid_payment
    payment.amount = 0
    assert_not payment.valid?
  end

  test "invalid with negative amount" do
    payment = valid_payment
    payment.amount = -1
    assert_not payment.valid?
  end

  test "invalid without status" do
    payment = valid_payment
    payment.status = nil
    assert_not payment.valid?
    assert payment.errors[:status].any?
  end

  test "invalid with unrecognized status" do
    payment = valid_payment
    payment.status = "refunded"
    assert_not payment.valid?
    assert payment.errors[:status].any?
  end

  test "valid for each allowed status" do
    %w[pending completed failed].each do |status|
      payment = valid_payment
      payment.status = status
      assert payment.valid?, "Expected status '#{status}' to be valid"
    end
  end

  test "fixture alice_payment is valid" do
    assert payments(:alice_payment).valid?
  end
end
