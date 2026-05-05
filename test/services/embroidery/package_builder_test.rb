require "test_helper"
require "fileutils"
require "tmpdir"

class Embroidery::PackageBuilderTest < ActiveSupport::TestCase
  setup do
    @tmp_root = Pathname.new(Dir.mktmpdir("package_builder_source_test", Rails.root.join("tmp")))
    @out_dir = Pathname.new(Dir.mktmpdir("package_builder_output_test", Rails.root.join("tmp")))
  end

  teardown do
    FileUtils.rm_rf(@tmp_root)
    FileUtils.rm_rf(@out_dir)
  end

  test "copies ready assets into the proposed s3 directory structure and writes metadata" do
    design_dir = @tmp_root.join("floral_bundle", "4x4", "rose_design__01")
    FileUtils.mkdir_p(design_dir)
    File.binwrite(design_dir.join("rose.pes"), "embroidery-binary")
    File.binwrite(design_dir.join("preview.jpg"), "image-binary")
    File.write(design_dir.join("metadata.json"), JSON.generate({ stitch_count: 8123, notes: "sample" }))

    result = Embroidery::PackageBuilder.new(root: @tmp_root, out_dir: @out_dir).call

    assert_equal 1, result.summary[:packaged_products]
    assert @out_dir.join("embroidery/floral-bundle/rose-design/4x4/download/01-rose.pes").file?
    assert @out_dir.join("embroidery/floral-bundle/rose-design/4x4/preview/01-preview.jpg").file?
    assert @out_dir.join("embroidery/floral-bundle/rose-design/4x4/metadata.json").file?

    metadata = JSON.parse(@out_dir.join("embroidery/floral-bundle/rose-design/4x4/metadata.json").read)
    assert_equal 8123, metadata["stitch_count"]
    assert_equal "sample", metadata.dig("source_metadata", "notes")
    assert @out_dir.join("manifest.json").file?
  end

  test "skips not-ready products by default" do
    design_dir = @tmp_root.join("holiday", "5x7", "tree_design")
    FileUtils.mkdir_p(design_dir)
    File.binwrite(design_dir.join("preview.png"), "image-binary")

    result = Embroidery::PackageBuilder.new(root: @tmp_root, out_dir: @out_dir).call

    assert_equal 0, result.summary[:packaged_products]
    assert_equal 1, result.summary[:skipped_products]
    refute @out_dir.join("embroidery").exist?
  end
end
