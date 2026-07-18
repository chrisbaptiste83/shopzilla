# frozen_string_literal: true

require "test_helper"

class DownloadsOwnershipTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @gloria = users(:gloria)
    sign_in @gloria
  end

  test "another user cannot download with alice's token" do
    get secure_download_path(token: download_accesses(:active_download).access_token)

    assert_response :not_found
  end
end
