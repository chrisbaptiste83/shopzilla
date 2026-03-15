require "test_helper"

class ShippingAddressTest < ActiveSupport::TestCase
  def valid_address
    ShippingAddress.new(
      order: orders(:alice_pending),
      full_name: "Gloria Smith",
      street_address: "456 Oak Avenue",
      city: "Austin",
      state: "TX",
      zip_code: "78701",
      country: "United States"
    )
  end

  test "valid with all required fields" do
    assert valid_address.valid?
  end

  test "invalid without full_name" do
    addr = valid_address
    addr.full_name = nil
    assert_not addr.valid?
    assert addr.errors[:full_name].any?
  end

  test "full_name must be at least 2 characters" do
    addr = valid_address
    addr.full_name = "A"
    assert_not addr.valid?
  end

  test "full_name cannot exceed 100 characters" do
    addr = valid_address
    addr.full_name = "A" * 101
    assert_not addr.valid?
  end

  test "invalid without street_address" do
    addr = valid_address
    addr.street_address = nil
    assert_not addr.valid?
    assert addr.errors[:street_address].any?
  end

  test "street_address must be at least 5 characters" do
    addr = valid_address
    addr.street_address = "123"
    assert_not addr.valid?
  end

  test "invalid without city" do
    addr = valid_address
    addr.city = nil
    assert_not addr.valid?
    assert addr.errors[:city].any?
  end

  test "invalid without state" do
    addr = valid_address
    addr.state = nil
    assert_not addr.valid?
    assert addr.errors[:state].any?
  end

  test "invalid without zip_code" do
    addr = valid_address
    addr.zip_code = nil
    assert_not addr.valid?
    assert addr.errors[:zip_code].any?
  end

  test "zip_code accepts 5-digit format" do
    addr = valid_address
    addr.zip_code = "12345"
    assert addr.valid?
  end

  test "zip_code accepts 5+4 extended format" do
    addr = valid_address
    addr.zip_code = "12345-6789"
    assert addr.valid?
  end

  test "zip_code rejects alphabetic input" do
    addr = valid_address
    addr.zip_code = "ABCDE"
    assert_not addr.valid?
    assert addr.errors[:zip_code].any?
  end

  test "zip_code rejects partial format" do
    addr = valid_address
    addr.zip_code = "1234"
    assert_not addr.valid?
  end

  test "invalid without country" do
    addr = valid_address
    addr.country = nil
    assert_not addr.valid?
    assert addr.errors[:country].any?
  end

  test "fixture alice_home is valid" do
    assert shipping_addresses(:alice_home).valid?
  end
end
