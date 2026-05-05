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

  desc "Build an S3-key-shaped package directory from ready embroidery source folders"
  task package: :environment do
    source_root = ENV["SOURCE_ROOT"]
    raise "SOURCE_ROOT is required" if source_root.blank?

    out_dir = Pathname.new(ENV.fetch("OUT_DIR", Rails.root.join("tmp", "embroidery_catalog_package").to_s))
    limit = ENV["LIMIT"]&.to_i
    require_preview = ActiveModel::Type::Boolean.new.cast(ENV.fetch("REQUIRE_PREVIEW", "false"))
    ready_only = ActiveModel::Type::Boolean.new.cast(ENV.fetch("READY_ONLY", "true"))
    overwrite = ActiveModel::Type::Boolean.new.cast(ENV.fetch("OVERWRITE", "false"))

    result = Embroidery::PackageBuilder.new(
      root: source_root,
      out_dir: out_dir,
      limit: limit,
      require_preview: require_preview,
      ready_only: ready_only,
      overwrite: overwrite
    ).call

    puts "Embroidery catalog package complete"
    puts "  Source root: #{result.source_root}"
    puts "  Output dir: #{result.out_dir}"
    puts "  Scanned products: #{result.summary[:scanned_products]}"
    puts "  Packaged products: #{result.summary[:packaged_products]}"
    puts "  Skipped products: #{result.summary[:skipped_products]}"
    puts "  Issues: #{result.summary[:issue_count]}"
    puts "  Manifest: #{out_dir.join("manifest.json")}"
  end

  desc "Delete packaged source directories from a reviewed package manifest; defaults to DRY_RUN=true"
  task cleanup: :environment do
    manifest_path = ENV["MANIFEST_PATH"]
    raise "MANIFEST_PATH is required" if manifest_path.blank?

    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
    force = ENV["CONFIRM"] == "DELETE"

    result = Embroidery::SourceCleanup.new(
      manifest_path: manifest_path,
      dry_run: dry_run,
      force: force
    ).call

    report_path = Pathname.new(manifest_path).dirname.join("cleanup_report.json")
    File.write(report_path, JSON.pretty_generate(result.to_h))

    puts "Embroidery source cleanup complete"
    puts "  Manifest: #{result.manifest_path}"
    puts "  Dry run: #{result.summary[:dry_run]}"
    puts "  Candidate directories: #{result.summary[:candidate_count]}"
    puts "  Existing directories: #{result.summary[:existing_count]}"
    puts "  Missing directories: #{result.summary[:missing_count]}"
    puts "  Deleted directories: #{result.summary[:deleted_count]}"
    puts "  Total bytes: #{result.summary[:total_bytes]}"
    puts "  Report: #{report_path}"
  end

  desc "Upload a reviewed package directly to S3 using the manifest's proposed S3 keys"
  task upload: :environment do
    manifest_path = ENV["MANIFEST_PATH"]
    raise "MANIFEST_PATH is required" if manifest_path.blank?

    dry_run  = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
    overwrite = ActiveModel::Type::Boolean.new.cast(ENV.fetch("OVERWRITE", "false"))
    bucket   = ENV["S3_BUCKET"]
    region   = ENV["S3_REGION"]

    result = Embroidery::S3Uploader.new(
      manifest_path: manifest_path,
      bucket: bucket,
      region: region,
      dry_run: dry_run,
      overwrite: overwrite
    ).call

    report_path = Pathname.new(manifest_path).dirname.join("upload_report.json")

    puts "Embroidery S3 upload #{dry_run ? '(DRY RUN) ' : ''}complete"
    puts "  Manifest:  #{result.manifest_path}"
    puts "  Bucket:    #{result.bucket}"
    puts "  Uploaded:  #{result.summary[:uploaded_count]} files"
    puts "  Skipped:   #{result.summary[:skipped_count]} files"
    puts "  Errors:    #{result.summary[:error_count]}"
    puts "  Total:     #{result.summary[:total_mb]} MB"
    puts "  Report:    #{report_path}"

    if result.errors.any?
      puts "\nFailed uploads:"
      result.errors.each { |e| puts "  #{e.s3_key}: #{e.error}" }
    end

    raise "Upload finished with #{result.summary[:error_count]} error(s)" if result.errors.any?
  end

  desc "Import packaged embroidery products into Rails from a reviewed manifest"
  task import: :environment do
    manifest_path = ENV["MANIFEST_PATH"]
    raise "MANIFEST_PATH is required" if manifest_path.blank?

    price_cents = ENV.fetch("IMPORT_PRICE_CENTS", "500").to_i
    overwrite_attachments = ActiveModel::Type::Boolean.new.cast(ENV.fetch("OVERWRITE_ATTACHMENTS", "true"))

    result = Embroidery::CatalogImporter.new(
      manifest_path: manifest_path,
      price_cents: price_cents,
      overwrite_attachments: overwrite_attachments
    ).call

    report_path = Pathname.new(manifest_path).dirname.join("import_report.json")
    File.write(report_path, JSON.pretty_generate(result.to_h))

    puts "Embroidery catalog import complete"
    puts "  Manifest: #{result.manifest_path}"
    puts "  Packaged products: #{result.summary[:packaged_products]}"
    puts "  Imported products: #{result.summary[:imported_products]}"
    puts "  Created products: #{result.summary[:created_products]}"
    puts "  Updated products: #{result.summary[:updated_products]}"
    puts "  Errors: #{result.summary[:error_count]}"
    puts "  Report: #{report_path}"
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
        stitch_count
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
          product[:preview_images].first&.dig(:proposed_s3_key),
          product.dig(:metadata, :stitch_count)
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
