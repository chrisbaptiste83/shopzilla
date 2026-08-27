ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "bcrypt"
require "fileutils"

builds_path = Rails.root.join("app/assets/builds")
FileUtils.mkdir_p(builds_path)
File.write(builds_path.join("application.css"), "") unless builds_path.join("application.css").exist?
File.write(builds_path.join("bundle.js"), "") unless builds_path.join("bundle.js").exist?

module ActiveSupport
  class TestCase
    configured_workers = ENV["PARALLEL_WORKERS"].to_i
    default_workers = RUBY_PLATFORM.include?("darwin") ? 1 : :number_of_processors
    parallel_workers = configured_workers.positive? ? configured_workers : default_workers
    parallelize(workers: parallel_workers)

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
