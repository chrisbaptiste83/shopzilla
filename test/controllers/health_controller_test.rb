# frozen_string_literal: true

require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "up" do
    get "/up"
    assert_response :success
  end

  test "healthz" do
    get "/healthz"
    assert_response :success
  end
end
