#!/usr/bin/env ruby

require "csv"
require "fileutils"
require "json"
require "pathname"
require "set"

class DesktopEmbroideryBatchExporter
  EMBROIDERY_EXTENSIONS = %w[.pes .dst .jef .exp .vp3 .hus .xxx].freeze
  IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .webp].freeze

  def initialize(source_root:, out_dir:, limit: nil, price_cents: 500)
    @source_root = Pathname.new(source_root).expand_path
    @out_dir = Pathname.new(out_dir).expand_path
    @limit = limit&.to_i
    @price_cents = price_cents.to_i
  end

  def call
    raise "source root does not exist: #{@source_root}" unless @source_root.directory?

    FileUtils.rm_rf(@out_dir)
    FileUtils.mkdir_p(@out_dir)

    candidates = []
    upload_rows = []

    each_design_dir.with_index do |design_dir, index|
      break if @limit && index >= @limit

      product = build_product(design_dir)
      next unless product

      candidates << product
    end

    products, issues = filter_collisions(candidates)

    products.each do |product|
      stage_product_assets(product, upload_rows)
    end

    write_outputs(products, upload_rows, issues, candidates.size)
  end

  private

  def each_design_dir
    Enumerator.new do |yielder|
      sorted_directories(@source_root).each do |category_dir|
        sorted_directories(category_dir).each do |size_dir|
          sorted_directories(size_dir).each do |design_dir|
            yielder << design_dir
          end
        end
      end
    end
  end

  def sorted_directories(path)
    path.children.select(&:directory?).sort_by { |entry| entry.basename.to_s.downcase }
  end

  def sorted_files(path)
    path.children.select(&:file?).sort_by { |entry| entry.basename.to_s.downcase }
  end

  def build_product(design_dir)
    category_dir = design_dir.parent.parent
    size_dir = design_dir.parent
    metadata = read_metadata(design_dir)

    embroidery_files = sorted_files(design_dir).select { |file| EMBROIDERY_EXTENSIONS.include?(file.extname.downcase) && file.size.positive? }
    return nil if embroidery_files.empty?

    image_files = sorted_files(design_dir).select { |file| IMAGE_EXTENSIONS.include?(file.extname.downcase) && file.size.positive? }
    design_name = design_dir.basename.to_s
    clean_name = metadata["clean_name"].to_s.strip
    normalized_name = clean_name.empty? ? normalize_design_name(design_name) : clean_name

    category_slug = slug(category_dir.basename.to_s)
    size_slug = slug(size_dir.basename.to_s)
    design_slug = slug(normalized_name)
    prefix = File.join("embroidery", category_slug, design_slug, size_slug)

    primary_file = embroidery_files.first
    preview_images = prioritize_images(image_files).first(2)

    {
      source_path: design_dir.to_s,
      source_relative_path: design_dir.relative_path_from(@source_root).to_s,
      category_name: category_dir.basename.to_s,
      category_slug: category_slug,
      design_name: design_name,
      design_slug: design_slug,
      size_name: size_dir.basename.to_s,
      size_slug: size_slug,
      title: build_title(normalized_name, size_dir.basename.to_s),
      price: @price_cents,
      file_format: primary_file.extname.delete_prefix(".").upcase,
      is_available: true,
      physical_product: false,
      shippable: false,
      dimensions: size_dir.basename.to_s,
      stitch_count: metadata["stitch_count"],
      description: build_description(metadata),
      color_count: metadata["color_count"],
      width_mm: metadata["width_mm"],
      height_mm: metadata["height_mm"],
      threads: metadata["threads"] || [],
      source_metadata: metadata,
      proposed_s3_prefix: prefix,
      primary_embroidery_file: file_entry(primary_file, File.join(prefix, "download", "01-#{primary_file.basename}")),
      preview_images: preview_images.each_with_index.map do |file, idx|
        file_entry(file, File.join(prefix, "preview", format("%02d-%s", idx + 1, file.basename.to_s)))
      end
    }
  end

  def file_entry(file, s3_key)
    {
      filename: file.basename.to_s,
      local_path: file.to_s,
      s3_key: s3_key,
      byte_size: file.size
    }
  end

  def prioritize_images(files)
    files.sort_by do |file|
      name = file.basename.to_s.downcase
      [ name.include?("grid") ? 1 : 0, name ]
    end
  end

  def read_metadata(design_dir)
    metadata_path = design_dir.join("metadata.json")
    return {} unless metadata_path.file?

    JSON.parse(metadata_path.read)
  rescue JSON::ParserError
    {}
  end

  def build_title(name, size)
    "#{humanize_name(name)} (#{size})"
  end

  def build_description(metadata)
    parts = []
    parts << "Stitch count: #{metadata["stitch_count"]}" if metadata["stitch_count"]
    parts << "Colors: #{metadata["color_count"]}" if metadata["color_count"]

    if metadata["width_mm"] && metadata["height_mm"]
      parts << format("Design size: %.1f x %.1f mm", metadata["width_mm"], metadata["height_mm"])
    end

    parts.join("\n")
  end

  def normalize_design_name(name)
    name.sub(/__\d+\z/, "").tr("_", " ").strip
  end

  def humanize_name(name)
    name.to_s.gsub(/[_\s]+/, " ").strip.split.map(&:capitalize).join(" ")
  end

  def slug(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
  end

  def stage_product_assets(product, upload_rows)
    files = [ product[:primary_embroidery_file], *product[:preview_images] ]

    files.each do |entry|
      destination = @out_dir.join("package", entry[:s3_key])
      FileUtils.mkdir_p(destination.dirname)
      FileUtils.cp(entry[:local_path], destination)

      upload_rows << [
        entry[:local_path],
        entry[:s3_key],
        entry[:byte_size],
        product[:title]
      ]
    end

    metadata_destination = @out_dir.join("package", product[:proposed_s3_prefix], "metadata.json")
    FileUtils.mkdir_p(metadata_destination.dirname)
    File.write(metadata_destination, JSON.pretty_generate(product[:source_metadata]))

    upload_rows << [
      metadata_destination.to_s,
      File.join(product[:proposed_s3_prefix], "metadata.json"),
      File.size(metadata_destination),
      product[:title]
    ]
  end

  def filter_collisions(products)
    issues = []
    collisions = products.group_by { |product| product[:proposed_s3_prefix] }.select { |_prefix, entries| entries.size > 1 }
    collision_paths = collisions.values.flatten.map { |product| product[:source_relative_path] }.to_set

    collisions.each do |prefix, entries|
      entries.each do |product|
        issues << {
          type: "duplicate_s3_prefix",
          proposed_s3_prefix: prefix,
          source_relative_path: product[:source_relative_path],
          title: product[:title]
        }
      end
    end

    filtered = products.reject { |product| collision_paths.include?(product[:source_relative_path]) }
    [ filtered, issues ]
  end

  def write_outputs(products, upload_rows, issues, scanned_count)
    File.write(@out_dir.join("products_import.json"), JSON.pretty_generate(products.map { |product| import_payload(product) }))
    write_products_csv(products)
    write_upload_manifest(upload_rows)
    write_issues(issues)
    write_summary(products, issues, scanned_count)
  end

  def import_payload(product)
    {
      category_name: product[:category_name],
      title: product[:title],
      price: product[:price],
      file_format: product[:file_format],
      is_available: product[:is_available],
      physical_product: product[:physical_product],
      shippable: product[:shippable],
      dimensions: product[:dimensions],
      stitch_count: product[:stitch_count],
      description: product[:description],
      source_relative_path: product[:source_relative_path],
      proposed_s3_prefix: product[:proposed_s3_prefix],
      primary_embroidery_s3_key: product[:primary_embroidery_file][:s3_key],
      preview_s3_keys: product[:preview_images].map { |image| image[:s3_key] }
    }
  end

  def write_products_csv(products)
    CSV.open(@out_dir.join("products_import.csv"), "wb") do |csv|
      csv << %w[
        category_name
        title
        price
        file_format
        is_available
        physical_product
        shippable
        dimensions
        stitch_count
        description
        source_relative_path
        proposed_s3_prefix
        primary_embroidery_s3_key
        preview_s3_key_1
        preview_s3_key_2
      ]

      products.each do |product|
        csv << [
          product[:category_name],
          product[:title],
          product[:price],
          product[:file_format],
          product[:is_available],
          product[:physical_product],
          product[:shippable],
          product[:dimensions],
          product[:stitch_count],
          product[:description],
          product[:source_relative_path],
          product[:proposed_s3_prefix],
          product[:primary_embroidery_file][:s3_key],
          product[:preview_images][0]&.dig(:s3_key),
          product[:preview_images][1]&.dig(:s3_key)
        ]
      end
    end
  end

  def write_upload_manifest(rows)
    CSV.open(@out_dir.join("upload_manifest.csv"), "wb") do |csv|
      csv << %w[local_path s3_key byte_size product_title]
      rows.each { |row| csv << row }
    end
  end

  def write_issues(issues)
    File.write(@out_dir.join("issues.json"), JSON.pretty_generate(issues))
  end

  def write_summary(products, issues, scanned_count)
    summary = {
      source_root: @source_root.to_s,
      out_dir: @out_dir.to_s,
      scanned_product_count: scanned_count,
      exportable_product_count: products.size,
      issue_count: issues.size,
      categories: products.map { |product| product[:category_name] }.uniq.sort,
      sizes: products.map { |product| product[:dimensions] }.uniq.sort
    }

    File.write(@out_dir.join("summary.json"), JSON.pretty_generate(summary))
  end
end

source_root = ENV["SOURCE_ROOT"] || "/Users/christopherbaptiste/Desktop/Embroidery Catalog/Bundles"
out_dir = ENV["OUT_DIR"] || "/Users/christopherbaptiste/Desktop/Development/Shopzilla/shopzilla/tmp/desktop_embroidery_export"
limit = ENV["LIMIT"]
price_cents = ENV["PRICE_CENTS"] || "500"

DesktopEmbroideryBatchExporter.new(
  source_root: source_root,
  out_dir: out_dir,
  limit: limit,
  price_cents: price_cents
).call
