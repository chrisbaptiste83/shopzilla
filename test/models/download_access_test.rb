require "test_helper"

class DownloadAccessTest < ActiveSupport::TestCase
  def valid_download_access
    DownloadAccess.new(
      user: users(:alice),
      product: products(:rose_design),
      access_token: SecureRandom.urlsafe_base64(32),
      expires_at: 30.days.from_now
    )
  end

  test "valid with required attributes" do
    assert valid_download_access.valid?
  end

  test "generates an access token on create when one is not provided" do
    da = DownloadAccess.create!(
      user: users(:alice),
      product: products(:rose_design),
      expires_at: 30.days.from_now
    )

    assert da.access_token.present?
  end

  test "invalid when an existing record loses its access_token" do
    da = valid_download_access
    da.save!
    da.access_token = nil
    assert_not da.valid?
    assert da.errors[:access_token].any?
  end

  test "access_token must be unique" do
    da = valid_download_access
    da.access_token = download_accesses(:active_download).access_token
    assert_not da.valid?
    assert da.errors[:access_token].any?
  end

  test "invalid without expires_at" do
    da = valid_download_access
    da.expires_at = nil
    assert_not da.valid?
    assert da.errors[:expires_at].any?
  end

  test "expired? returns true when past expires_at" do
    assert download_accesses(:expired_download).expired?
  end

  test "expired? returns false when before expires_at" do
    assert_not download_accesses(:active_download).expired?
  end

  test "active scope includes non-expired records" do
    assert_includes DownloadAccess.active, download_accesses(:active_download)
  end

  test "active scope excludes expired records" do
    refute_includes DownloadAccess.active, download_accesses(:expired_download)
  end

  test "order association is optional" do
    da = valid_download_access
    da.order = nil
    assert da.valid?
  end
end
