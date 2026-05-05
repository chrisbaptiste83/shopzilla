require "test_helper"
require "fileutils"

class Embroidery::CatalogAuditorTest < ActiveSupport::TestCase
  setup do
    @tmp_root = Rails.root.join("tmp", "catalog_auditor_test")
    FileUtils.rm_rf(@tmp_root)
    FileUtils.mkdir_p(@tmp_root)
  end

  teardown do
    FileUtils.rm_rf(@tmp_root)
  end

  test "builds an S3-ready manifest entry for a valid design folder" do
    design_dir = @tmp_root.join("floral_bundle", "4x4", "rose_design__01")
    FileUtils.mkdir_p(design_dir)
    File.binwrite(design_dir.join("rose.pes"), "embroidery-binary")
    File.binwrite(design_dir.join("preview.jpg"), "image-binary")
    File.write(design_dir.join("metadata.json"), JSON.generate({ stitch_count: 8123 }))

    result = Embroidery::CatalogAuditor.new(root: @tmp_root).call
    product = result.products.first

    assert_equal 1, result.summary[:scanned_products]
    assert_equal "ready", product[:status]
    assert_equal "embroidery/floral-bundle/rose-design/4x4", product[:proposed_s3_prefix]
    assert_equal "Rose design (4x4)", product.dig(:design, :title)
    assert_equal 8123, product.dig(:metadata, :stitch_count)
    assert_equal "embroidery/floral-bundle/rose-design/4x4/download/01-rose.pes", product[:embroidery_files].first[:proposed_s3_key]
    assert_equal "floral_bundle/4x4/rose_design__01", product[:source_relative_path]
  end

  test "flags missing embroidery files" do
    design_dir = @tmp_root.join("holiday", "5x7", "tree_design")
    FileUtils.mkdir_p(design_dir)
    File.binwrite(design_dir.join("preview.png"), "image-binary")

    result = Embroidery::CatalogAuditor.new(root: @tmp_root).call

    assert_equal 1, result.summary[:products_missing_embroidery_file]
    assert_equal "missing_embroidery_file", result.products.first[:status]
    assert_equal "missing_embroidery_file", result.issues.first[:type]
  end

  test "flags duplicate normalized S3 prefixes" do
    first_dir = @tmp_root.join("animals", "4x4", "fox_design")
    second_dir = @tmp_root.join("animals", "4x4", "fox_design__01")
    FileUtils.mkdir_p(first_dir)
    FileUtils.mkdir_p(second_dir)
    File.binwrite(first_dir.join("fox.pes"), "first")
    File.binwrite(second_dir.join("fox_copy.pes"), "second")

    result = Embroidery::CatalogAuditor.new(root: @tmp_root).call
    duplicate_issues = result.issues.select { |issue| issue[:type] == "duplicate_s3_prefix" }

    assert_equal 2, duplicate_issues.size
    assert_equal 2, result.summary[:duplicate_s3_prefixes]
  end

  test "flags invalid metadata json without dropping the product from the audit" do
    design_dir = @tmp_root.join("seasonal", "5x7", "pumpkin_patch")
    FileUtils.mkdir_p(design_dir)
    File.binwrite(design_dir.join("pumpkin.pes"), "embroidery-binary")
    File.write(design_dir.join("metadata.json"), "{not-json")

    result = Embroidery::CatalogAuditor.new(root: @tmp_root).call
    product = result.products.first

    assert_equal "ready", product[:status]
    assert product.dig(:metadata, :error).present?
    assert_equal 1, result.summary[:products_with_invalid_metadata]
    assert_equal "invalid_metadata_json", result.issues.first[:type]
  end
end
