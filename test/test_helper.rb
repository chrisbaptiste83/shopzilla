ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "bcrypt"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Load all fixtures
    fixtures :all
  end
end

# Devise sign_in/sign_out helpers for integration tests
class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Pass a modern Chrome UA on every request so allow_browser versions: :modern passes
  MODERN_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
              "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

  setup do
    @ua = { "User-Agent" => MODERN_UA }
  end
end
