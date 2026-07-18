# frozen_string_literal: true

require "test_helper"

class StripeTerminalServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
  end

  test "rejects float dollar amounts" do
    error = assert_raises(StripeTerminalService::ValidationError) do
      StripeTerminalService.create_payment_intent(user: @user, amount_cents: 12.5)
    end
    assert_match(/integer/, error.message)
  end

  test "rejects amounts below minimum" do
    error = assert_raises(StripeTerminalService::ValidationError) do
      StripeTerminalService.create_payment_intent(user: @user, amount_cents: 1)
    end
    assert_match(/between/, error.message)
  end

  test "rejects blank payment intent id" do
    error = assert_raises(StripeTerminalService::ValidationError) do
      StripeTerminalService.capture!(user: @user, payment_intent_id: " ")
    end
    assert_match(/required/, error.message)
  end
end
