require "test_helper"
require "fileutils"

class Embroidery::SourceCleanupTest < ActiveSupport::TestCase
  setup do
    @source_root = Rails.root.join("tmp", "source_cleanup_source_test")
    @package_dir = Rails.root.join("tmp", "source_cleanup_package_test")
    FileUtils.rm_rf(@source_root)
    FileUtils.rm_rf(@package_dir)
    FileUtils.mkdir_p(@source_root)
    FileUtils.mkdir_p(@package_dir)
  end

  teardown do
    FileUtils.rm_rf(@source_root)
    FileUtils.rm_rf(@package_dir)
  end

  test "reports packaged source directories without deleting them in dry-run mode" do
    design_dir = @source_root.join("floral_bundle", "4x4", "rose_design__01")
    FileUtils.mkdir_p(design_dir)
    File.binwrite(design_dir.join("rose.pes"), "embroidery-binary")

    manifest_path = @package_dir.join("manifest.json")
    File.write(
      manifest_path,
      JSON.pretty_generate(
        source_root: @source_root.to_s,
        packaged_products: [
          {
            source_path: design_dir.to_s,
            source_relative_path: "floral_bundle/4x4/rose_design__01",
            proposed_s3_prefix: "embroidery/floral-bundle/rose-design/4x4"
          }
        ]
      )
    )

    result = Embroidery::SourceCleanup.new(manifest_path: manifest_path).call

    assert_equal 1, result.summary[:candidate_count]
    assert_equal 0, result.summary[:deleted_count]
    assert_equal "would_delete", result.candidates.first[:action]
    assert design_dir.directory?
  end

  test "deletes packaged source directories only when force is explicitly enabled" do
    design_dir = @source_root.join("floral_bundle", "4x4", "rose_design__01")
    FileUtils.mkdir_p(design_dir)
    File.binwrite(design_dir.join("rose.pes"), "embroidery-binary")

    manifest_path = @package_dir.join("manifest.json")
    File.write(
      manifest_path,
      JSON.pretty_generate(
        source_root: @source_root.to_s,
        packaged_products: [
          {
            source_path: design_dir.to_s,
            source_relative_path: "floral_bundle/4x4/rose_design__01",
            proposed_s3_prefix: "embroidery/floral-bundle/rose-design/4x4"
          }
        ]
      )
    )

    result = Embroidery::SourceCleanup.new(manifest_path: manifest_path, dry_run: false, force: true).call

    assert_equal 1, result.summary[:deleted_count]
    assert_equal "deleted", result.candidates.first[:action]
    refute design_dir.exist?
  end
end
