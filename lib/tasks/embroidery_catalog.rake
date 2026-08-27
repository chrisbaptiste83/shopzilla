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
    render_previews = ActiveModel::Type::Boolean.new.cast(ENV.fetch("RENDER_PREVIEWS", "true"))

    result = Embroidery::PackageBuilder.new(
      root: source_root,
      out_dir: out_dir,
      limit: limit,
      require_preview: require_preview,
      ready_only: ready_only,
      overwrite: overwrite,
      render_previews: render_previews
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

  desc "Render product preview images from PES files directly into an existing package directory"
  task render_previews: :environment do
    manifest_path = ENV["MANIFEST_PATH"]
    raise "MANIFEST_PATH is required" if manifest_path.blank?

    manifest = JSON.parse(File.read(manifest_path))
    out_dir   = Pathname.new(File.dirname(manifest_path))
    products  = manifest["packaged_products"] || []

    rendered = 0
    failed   = 0

    products.each do |product|
      pes_file = (product["embroidery_files"] || []).find { |f| f["filename"]&.downcase&.end_with?(".pes") }
      next unless pes_file

      source_root = manifest["source_root"]
      pes_path    = File.join(source_root, pes_file["source_relative_path"] || "")
      next unless File.exist?(pes_path)

      prefix      = product["proposed_s3_prefix"]
      s3_key      = File.join(prefix, "preview", "01-preview.png")
      output_path = out_dir.join(s3_key)

      begin
        Embroidery::PreviewRenderer.new(pes_path: pes_path, output_path: output_path).call
        rendered += 1
        puts "  rendered: #{s3_key}"
      rescue => error
        failed += 1
        warn "  FAILED #{s3_key}: #{error.message}"
      end
    end

    puts "Render previews complete: #{rendered} rendered, #{failed} failed"
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

  # ─────────────────────────────────────────────────────────────────────────
  # Import directly from the flat Embroidery Catalog folder on disk.
  #
  # Expected structure:
  #   SOURCE_ROOT/
  #     <Design Name>/
  #       metadata.json   (source_path, stitch_count, clean_name, categories, threads)
  #       <Design Name>.png
  #       <Design Name>_grid.png   (optional)
  #
  # Usage:
  #   SOURCE_ROOT="~/Desktop/Embroidery Files/Embroidery Catalog" \
  #   LIMIT=5 rails embroidery_catalog:import_flat
  #
  # Optional env vars:
  #   LIMIT              max designs to import (default: all)
  #   RENDER_PREVIEW     true/false — render new isolated previews from PES (default: true)
  #   PRICE_CENTS        product price in cents (default: 500)
  #   CATEGORY_MAP_JSON  JSON object overriding category label mapping
  # ─────────────────────────────────────────────────────────────────────────
  desc "Import from a flat Embroidery Catalog directory (metadata.json + PES per design)"
  task import_flat: :environment do
    require "json"
    require "open3"

    source_root   = ENV["SOURCE_ROOT"]
    raise "SOURCE_ROOT is required" if source_root.blank?

    catalog_root  = Pathname.new(source_root).expand_path
    raise "SOURCE_ROOT does not exist: #{catalog_root}" unless catalog_root.directory?

    limit          = ENV["LIMIT"]&.to_i
    render_preview = ActiveModel::Type::Boolean.new.cast(ENV.fetch("RENDER_PREVIEW", "true"))
    price_cents    = ENV.fetch("PRICE_CENTS", "500").to_i
    preview_script = Rails.root.join("scripts", "render_pes.py")

    default_category_labels = {
      "misc"        => "Miscellaneous",
      "animals"     => "Animals",
      "baby"        => "Baby & Kids",
      "religious"   => "Religious",
      "alesandro"   => "Alesandro",
      "flowermono"  => "Floral & Monogram",
      "clown"       => "Clowns & Circus",
      "christmas"   => "Christmas",
      "holiday"     => "Holidays",
      "sports"      => "Sports",
      "alphabet"    => "Alphabet",
      "border"      => "Borders",
      "butterfly"   => "Butterflies",
      "bird"        => "Birds",
      "flower"      => "Flowers",
      "nature"      => "Nature",
      "cartoon"     => "Cartoons",
      "seasonal"    => "Seasonal"
    }.freeze

    category_labels = if ENV["CATEGORY_MAP_JSON"].present?
      default_category_labels.merge(JSON.parse(ENV["CATEGORY_MAP_JSON"]))
    else
      default_category_labels
    end

    design_dirs = catalog_root.children.select(&:directory?).sort_by { |d| d.basename.to_s.downcase }
    design_dirs = design_dirs.first(limit) if limit&.positive?

    created  = 0
    updated  = 0
    skipped  = 0
    errors   = []

    design_dirs.each do |design_dir|
      meta_file = design_dir.join("metadata.json")
      next unless meta_file.file?

      begin
        meta        = JSON.parse(meta_file.read)
        raw_name    = (meta["clean_name"].presence || design_dir.basename.to_s).strip
        clean_name  = raw_name.length < 3 ? "#{raw_name} Design" : raw_name
        pes_path    = meta["source_path"].presence
        stitch_count = meta["stitch_count"]
        cats        = Array(meta["categories"]).reject { |c| c == "misc" }
        cat_key     = cats.first || "misc"
        cat_label   = category_labels.fetch(cat_key) { cat_key.tr("_", " ").humanize }

        category = Category.find_or_create_by!(name: cat_label)
        product  = Product.find_or_initialize_by(title: clean_name, category: category)
        is_new   = product.new_record?

        product.price            = price_cents if product.price.blank? || product.price.to_i <= 0
        product.stitch_count     = stitch_count if stitch_count.present?
        product.is_available     = true  if product.is_available.nil?
        product.physical_product = false if product.physical_product.nil?
        product.shippable        = false if product.shippable.nil?

        if product.file_format.blank? && pes_path.present?
          product.file_format = File.extname(pes_path).delete_prefix(".").upcase
        end

        if product.description.blank?
          product.description = build_flat_description(clean_name, cat_label, stitch_count)
        end

        product.save!

        # ── Preview image ────────────────────────────────────────────────
        if !product.images.attached? || is_new
          preview_attached = false

          if render_preview && pes_path.present? && File.exist?(pes_path)
            tmp = Tempfile.new(["preview", ".png"])
            begin
              _out, err, status = Open3.capture3(
                "python3", preview_script.to_s, pes_path, tmp.path,
                "--style", "light", "--trim-guides"
              )
              if status.success? && File.size(tmp.path) > 0
                product.images.attach(
                  io:           File.open(tmp.path, "rb"),
                  filename:     "#{clean_name.parameterize}-isolated.png",
                  content_type: "image/png",
                  metadata:     Product.image_metadata_for(
                    filename: "#{clean_name.parameterize}-isolated.png",
                    role: "primary",
                    render_style: "light"
                  )
                )
                preview_attached = true
              else
                warn "  preview render failed for #{clean_name}: #{err.strip}"
              end
            ensure
              tmp.close
              tmp.unlink
            end
          end

          # Fall back to existing catalog PNG if render failed or skipped
          unless preview_attached
            existing_png = design_dir.glob("*.png").reject { |f| f.basename.to_s.include?("_grid") }.first
            if existing_png&.file?
              product.images.attach(
                io:           File.open(existing_png, "rb"),
                filename:     existing_png.basename.to_s,
                content_type: "image/png",
                metadata:     Product.image_metadata_for(filename: existing_png.basename.to_s, role: "primary")
              )
            end
          end
        end

        # ── Embroidery file ──────────────────────────────────────────────
        if !product.embroidery_file.attached? && pes_path.present? && File.exist?(pes_path)
          product.embroidery_file.attach(
            io:           File.open(pes_path, "rb"),
            filename:     File.basename(pes_path),
            content_type: "application/octet-stream"
          )
        end

        is_new ? (created += 1) : (updated += 1)
        puts "  #{is_new ? '+' : '~'} #{clean_name} [#{cat_label}]#{stitch_count ? " (#{stitch_count.to_s.reverse.scan(/\d{1,3}/).join(',').reverse} stitches)" : ''}"

      rescue => e
        errors << { design: design_dir.basename.to_s, error: e.message }
        warn "  ERROR #{design_dir.basename}: #{e.message}"
      end
    end

    puts "\nDone."
    puts "  Created: #{created} | Updated: #{updated} | Skipped: #{skipped} | Errors: #{errors.size}"
    puts "  Total products in DB: #{Product.count}"
  end

  def build_flat_description(name, category_label, stitch_count)
    lines = ["#{name} embroidery design."]
    if stitch_count.present?
      formatted = stitch_count.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      lines << "Features #{formatted} stitches for a detailed, professional finish."
    end
    lines << "Part of the #{category_label} collection." if category_label.present?
    lines << "Works with most home and commercial embroidery machines. Instant digital download included."
    lines.join(" ")
  end
end
