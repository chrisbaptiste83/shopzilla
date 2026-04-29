require "csv"
require "fileutils"
require "json"

namespace :embroidery_catalog do
  desc "Audit an embroidery source directory and export an S3-ready manifest"
  task audit: :environment do
    source_root = ENV["SOURCE_ROOT"]
    raise "SOURCE_ROOT is required" if source_root.blank?

    out_dir = Pathname.new(ENV.fetch("OUT_DIR", Rails.root.join("tmp", "embroidery_catalog_audit").to_s))
    limit = ENV["LIMIT"]&.to_i
    require_preview = ActiveModel::Type::Boolean.new.cast(ENV.fetch("REQUIRE_PREVIEW", "false"))

    result = Embroidery::CatalogAuditor.new(
      root: source_root,
      limit: limit,
      require_preview: require_preview
    ).call

    FileUtils.mkdir_p(out_dir)

    manifest_path = out_dir.join("manifest.json")
    products_csv_path = out_dir.join("products.csv")
    issues_csv_path = out_dir.join("issues.csv")

    File.write(manifest_path, JSON.pretty_generate(result.to_h))
    write_products_csv(products_csv_path, result.products)
    write_issues_csv(issues_csv_path, result.issues)

    puts "Embroidery catalog audit complete"
    puts "  Source root: #{result.source_root}"
    puts "  Products scanned: #{result.summary[:scanned_products]}"
    puts "  Ready products: #{result.summary[:ready_products]}"
    puts "  Issues: #{result.summary[:issue_count]}"
    puts "  Manifest: #{manifest_path}"
    puts "  Products CSV: #{products_csv_path}"
    puts "  Issues CSV: #{issues_csv_path}"
  end

  def write_products_csv(path, products)
    CSV.open(path, "wb") do |csv|
      csv << %w[
        source_relative_path
        category_slug
        design_slug
        size_slug
        status
        proposed_s3_prefix
        primary_embroidery_key
        primary_preview_key
      ]

      products.each do |product|
        csv << [
          product[:source_relative_path],
          product.dig(:category, :slug),
          product.dig(:design, :slug),
          product.dig(:size, :slug),
          product[:status],
          product[:proposed_s3_prefix],
          product[:embroidery_files].first&.dig(:proposed_s3_key),
          product[:preview_images].first&.dig(:proposed_s3_key)
        ]
      end
    end
  end

  def write_issues_csv(path, issues)
    CSV.open(path, "wb") do |csv|
      csv << %w[type source_relative_path proposed_s3_prefix]

      issues.each do |issue|
        csv << [
          issue[:type],
          issue[:source_relative_path],
          issue[:proposed_s3_prefix]
        ]
      end
    end
  end
end
