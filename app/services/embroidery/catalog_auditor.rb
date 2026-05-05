require "digest"
require "json"

module Embroidery
  class CatalogAuditor
    EMBROIDERY_EXTENSIONS = %w[.pes .dst .jef .exp .vp3 .hus .xxx].freeze
    IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .webp].freeze

    Result = Struct.new(:source_root, :products, :issues, :summary, keyword_init: true) do
      def to_h
        {
          source_root: source_root,
          summary: summary,
          issues: issues,
          products: products
        }
      end
    end

    def initialize(root:, limit: nil, require_preview: false)
      @root = Pathname.new(root).expand_path
      @limit = limit&.to_i
      @require_preview = require_preview
    end

    def call
      raise ArgumentError, "source root does not exist: #{@root}" unless @root.exist?
      raise ArgumentError, "source root is not a directory: #{@root}" unless @root.directory?

      products = []
      issues = []

      each_design_directory.with_index do |design_dir, index|
        break if @limit.present? && index >= @limit

        product = build_product_entry(design_dir)
        products << product
        issues.concat(build_product_issues(product))
      end

      issues.concat(build_collision_issues(products))

      Result.new(
        source_root: @root.to_s,
        products: products,
        issues: issues,
        summary: build_summary(products, issues)
      )
    end

    private

    def each_design_directory
      Enumerator.new do |yielder|
        sorted_directories(@root).each do |category_dir|
          sorted_directories(category_dir).each do |size_dir|
            sorted_directories(size_dir).each do |design_dir|
              yielder << design_dir
            end
          end
        end
      end
    end

    def sorted_directories(path)
      path.children.select(&:directory?).sort_by { |child| child.basename.to_s.downcase }
    end

    def sorted_files(path)
      path.children.select(&:file?).sort_by { |child| child.basename.to_s.downcase }
    end

    def build_product_entry(design_dir)
      size_dir = design_dir.parent
      category_dir = size_dir.parent
      metadata = read_metadata(design_dir)

      embroidery_files = sorted_files(design_dir).select { |file| embroidery_file?(file) && file.size.positive? }
      image_files = sorted_files(design_dir).select { |file| image_file?(file) && file.size.positive? }

      category_name = category_dir.basename.to_s
      size_name = size_dir.basename.to_s
      design_name = design_dir.basename.to_s
      normalized_design_name = normalize_design_name(design_name)

      category_slug = normalize_slug(category_name)
      design_slug = normalize_slug(normalized_design_name)
      size_slug = normalize_slug(size_name)

      proposed_prefix = File.join("embroidery", category_slug, design_slug, size_slug)

      {
        source_path: design_dir.to_s,
        source_relative_path: relative_path(design_dir),
        category: {
          raw: category_name,
          slug: category_slug,
          label: category_name.tr("_", " ").humanize
        },
        size: {
          raw: size_name,
          slug: size_slug,
          label: size_name.tr("_", " ")
        },
        design: {
          raw: design_name,
          normalized: normalized_design_name,
          slug: design_slug,
          title: build_title(normalized_design_name, size_name)
        },
        metadata: metadata,
        status: build_status(embroidery_files, image_files),
        embroidery_files: serialize_files(embroidery_files, proposed_prefix, "download"),
        preview_images: serialize_files(image_files, proposed_prefix, "preview"),
        proposed_s3_prefix: proposed_prefix,
        proposed_metadata_key: File.join(proposed_prefix, "metadata.json")
      }
    end

    def build_status(embroidery_files, image_files)
      return "missing_embroidery_file" if embroidery_files.empty?
      return "missing_preview_image" if @require_preview && image_files.empty?

      "ready"
    end

    def build_product_issues(product)
      issues = []

      if product[:status] != "ready"
        issues << {
          type: product[:status],
          source_relative_path: product[:source_relative_path],
          proposed_s3_prefix: product[:proposed_s3_prefix]
        }
      end

      if product.dig(:metadata, :error).present?
        issues << {
          type: "invalid_metadata_json",
          source_relative_path: product[:source_relative_path],
          proposed_s3_prefix: product[:proposed_s3_prefix],
          metadata_path: product.dig(:metadata, :source_relative_path)
        }
      end

      issues
    end

    def build_collision_issues(products)
      products
        .group_by { |product| product[:proposed_s3_prefix] }
        .select { |_prefix, entries| entries.size > 1 }
        .flat_map do |prefix, entries|
          entries.map do |entry|
            {
              type: "duplicate_s3_prefix",
              source_relative_path: entry[:source_relative_path],
              proposed_s3_prefix: prefix
            }
          end
        end
    end

    def build_summary(products, issues)
      {
        scanned_products: products.size,
        ready_products: products.count { |product| product[:status] == "ready" },
        products_missing_embroidery_file: products.count { |product| product[:status] == "missing_embroidery_file" },
        products_missing_preview_image: products.count { |product| product[:status] == "missing_preview_image" },
        products_with_invalid_metadata: products.count { |product| product.dig(:metadata, :error).present? },
        duplicate_s3_prefixes: issues.count { |issue| issue[:type] == "duplicate_s3_prefix" },
        issue_count: issues.size
      }
    end

    def serialize_files(files, proposed_prefix, asset_folder)
      files.map.with_index(1) do |file, index|
        {
          filename: file.basename.to_s,
          source_relative_path: relative_path(file),
          byte_size: file.size,
          sha256: Digest::SHA256.file(file).hexdigest,
          proposed_s3_key: File.join(proposed_prefix, asset_folder, format("%02d-%s", index, file.basename.to_s))
        }
      end
    end

    def relative_path(path)
      path.relative_path_from(@root).to_s
    end

    def read_metadata(design_dir)
      metadata_file = design_dir.join("metadata.json")
      return empty_metadata unless metadata_file.file?

      parsed = JSON.parse(metadata_file.read)

      {
        source_relative_path: relative_path(metadata_file),
        stitch_count: parsed["stitch_count"],
        raw: parsed
      }
    rescue JSON::ParserError => error
      {
        source_relative_path: relative_path(metadata_file),
        stitch_count: nil,
        raw: nil,
        error: "invalid_json",
        error_message: error.message
      }
    end

    def empty_metadata
      {
        source_relative_path: nil,
        stitch_count: nil,
        raw: nil
      }
    end

    def normalize_design_name(name)
      name.sub(/__\d+\z/, "").tr("_", " ").squish
    end

    def normalize_slug(value)
      value.to_s.tr("_", "-").parameterize(separator: "-")
    end

    def build_title(design_name, size_name)
      "#{design_name.capitalize} (#{size_name.tr('_', ' ')})"
    end

    def embroidery_file?(file)
      EMBROIDERY_EXTENSIONS.include?(file.extname.downcase)
    end

    def image_file?(file)
      IMAGE_EXTENSIONS.include?(file.extname.downcase)
    end
  end
end
