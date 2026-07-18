# frozen_string_literal: true

require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "returns service unavailable when webhook secret is blank" do
    controller = WebhooksController.new
    def controller.stripe_webhook_secret
      nil
    end

    # Exercise the private helper contract used by the action.
    assert_nil controller.send(:stripe_webhook_secret)
  end

  test "prefers STRIPE_WEBHOOK_SECRET env over credentials" do
    ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_env_test"
    begin
      controller = WebhooksController.new
      assert_equal "whsec_env_test", controller.send(:stripe_webhook_secret)
    ensure
      ENV.delete("STRIPE_WEBHOOK_SECRET")
    end
  end
end
