require "test_helper"
require "fileutils"

class Embroidery::CatalogImporterTest < ActiveSupport::TestCase
  setup do
    @package_dir = Rails.root.join("tmp", "catalog_importer_package_test")
    FileUtils.rm_rf(@package_dir)
    FileUtils.mkdir_p(@package_dir.join("embroidery/floral-bundle/rose-design/4x4/download"))
    FileUtils.mkdir_p(@package_dir.join("embroidery/floral-bundle/rose-design/4x4/preview"))

    File.binwrite(@package_dir.join("embroidery/floral-bundle/rose-design/4x4/download/01-rose.pes"), "embroidery-binary")
    File.binwrite(@package_dir.join("embroidery/floral-bundle/rose-design/4x4/preview/01-preview.jpg"), "image-binary")
    File.binwrite(@package_dir.join("embroidery/floral-bundle/rose-design/4x4/preview/02-detail.jpg"), "detail-image-binary")

    File.write(
      @package_dir.join("manifest.json"),
      JSON.pretty_generate(
        packaged_products: [
          {
            source_path: "/tmp/source/floral_bundle/4x4/rose_design__01",
            source_relative_path: "floral_bundle/4x4/rose_design__01",
            proposed_s3_prefix: "embroidery/floral-bundle/rose-design/4x4",
            category: {
              raw: "floral_bundle",
              slug: "floral-bundle",
              label: "Floral bundle"
            },
            size: {
              raw: "4x4",
              slug: "4x4",
              label: "4x4"
            },
            design: {
              raw: "rose_design__01",
              normalized: "rose design",
              slug: "rose-design",
              title: "Rose design (4x4)"
            },
            metadata: {
              stitch_count: 8123,
              raw: {
                stitch_count: 8123
              }
            },
            embroidery_files: [
              {
                filename: "rose.pes",
                proposed_s3_key: "embroidery/floral-bundle/rose-design/4x4/download/01-rose.pes"
              }
            ],
            preview_images: [
              {
                filename: "preview.jpg",
                proposed_s3_key: "embroidery/floral-bundle/rose-design/4x4/preview/01-preview.jpg",
                render_style: "light"
              },
              {
                filename: "detail.jpg",
                proposed_s3_key: "embroidery/floral-bundle/rose-design/4x4/preview/02-detail.jpg",
                render_style: "detail"
              }
            ]
          }
        ]
      )
    )
  end

  teardown do
    FileUtils.rm_rf(@package_dir)
  end

  test "creates a digital product with attachments from a reviewed package manifest" do
    assert_difference -> { Category.count }, 1 do
      assert_difference -> { Product.count }, 1 do
        result = Embroidery::CatalogImporter.new(manifest_path: @package_dir.join("manifest.json")).call

        assert_equal 1, result.summary[:imported_products]
        assert_equal 0, result.summary[:error_count]
      end
    end

    product = Product.find_by!(title: "Rose design (4x4)")
    assert_equal "Floral bundle", product.category.name
    assert_equal 500, product.price
    assert_equal "PES", product.file_format
    assert_equal "4x4", product.dimensions
    assert_equal 8123, product.stitch_count
    assert_equal "Rose design embroidery design, available in 4x4. Features 8,123 stitches for a detailed, professional finish. Part of the Floral bundle collection. Works with most home and commercial embroidery machines. Instant digital download included.", product.description.to_plain_text.strip
    assert product.embroidery_file.attached?
    assert_equal 2, product.images.count
    assert_equal "preview.jpg", product.primary_image.filename.to_s
    assert_equal "light", product.primary_image.blob.metadata["render_style"]
    assert_equal "primary", product.primary_image.blob.metadata["image_role"]
    assert_equal "alternate", product.image_for_style("detail").blob.metadata["image_role"]
    assert_equal "product_preview", product.images.first.blob.metadata["asset_kind"]
    assert_equal "downloads/embroidery/floral-bundle/rose-design/4x4/01-rose.pes", product.embroidery_file.blob.key
    assert_equal "products/images/floral-bundle/rose-design/4x4/01-preview.jpg", product.images.first.blob.key
  end
end
