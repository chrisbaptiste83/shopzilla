require "fileutils"
require "json"
require "set"

module Embroidery
  class PackageBuilder
    Result = Struct.new(
      :source_root,
      :out_dir,
      :packaged_products,
      :skipped_products,
      :issues,
      :summary,
      keyword_init: true
    ) do
      def to_h
        {
          source_root: source_root,
          out_dir: out_dir,
          summary: summary,
          issues: issues,
          packaged_products: packaged_products,
          skipped_products: skipped_products
        }
      end
    end

    def initialize(root:, out_dir:, limit: nil, require_preview: false, ready_only: true, overwrite: false)
      @root = Pathname.new(root).expand_path
      @out_dir = Pathname.new(out_dir).expand_path
      @limit = limit
      @require_preview = require_preview
      @ready_only = ready_only
      @overwrite = overwrite
    end

    def call
      audit = CatalogAuditor.new(root: @root, limit: @limit, require_preview: @require_preview).call

      prepare_output_directory!

      packaged_products = []
      skipped_products = []
      seen_prefixes = Set.new

      audit.products.each do |product|
        if @ready_only && product[:status] != "ready"
          skipped_products << skip_entry(product, "status_not_ready")
          next
        end

        prefix = product[:proposed_s3_prefix]
        if seen_prefixes.include?(prefix)
          skipped_products << skip_entry(product, "duplicate_s3_prefix")
          next
        end

        seen_prefixes << prefix
        packaged_products << package_product(product)
      end

      result = Result.new(
        source_root: @root.to_s,
        out_dir: @out_dir.to_s,
        packaged_products: packaged_products,
        skipped_products: skipped_products,
        issues: audit.issues,
        summary: build_summary(audit, packaged_products, skipped_products)
      )

      File.write(@out_dir.join("manifest.json"), JSON.pretty_generate(result.to_h))
      result
    end

    private

    def prepare_output_directory!
      return FileUtils.mkdir_p(@out_dir) unless @out_dir.exist?

      if @overwrite
        FileUtils.rm_rf(@out_dir)
        FileUtils.mkdir_p(@out_dir)
        return
      end

      return if @out_dir.children.empty?

      raise ArgumentError, "output directory already exists and is not empty: #{@out_dir}"
    end

    def package_product(product)
      copy_assets(product[:embroidery_files])
      copy_assets(product[:preview_images])
      write_metadata(product)

      product.merge(
        packaged_at: Time.current.iso8601,
        packaged_file_count: product[:embroidery_files].size + product[:preview_images].size + 1
      )
    end

    def copy_assets(files)
      files.each do |file|
        source = @root.join(file[:source_relative_path])
        destination = @out_dir.join(file[:proposed_s3_key])
        FileUtils.mkdir_p(destination.dirname)
        FileUtils.cp(source, destination)
      end
    end

    def write_metadata(product)
      payload = {
        category: product[:category],
        design: product[:design],
        size: product[:size],
        title: product.dig(:design, :title),
        source_relative_path: product[:source_relative_path],
        stitch_count: product.dig(:metadata, :stitch_count),
        source_metadata: product.dig(:metadata, :raw),
        embroidery_files: product[:embroidery_files].map { |file| file.slice(:filename, :byte_size, :sha256, :proposed_s3_key) },
        preview_images: product[:preview_images].map { |file| file.slice(:filename, :byte_size, :sha256, :proposed_s3_key) }
      }

      destination = @out_dir.join(product[:proposed_metadata_key])
      FileUtils.mkdir_p(destination.dirname)
      File.write(destination, JSON.pretty_generate(payload))
    end

    def skip_entry(product, reason)
      {
        source_path: product[:source_path],
        source_relative_path: product[:source_relative_path],
        proposed_s3_prefix: product[:proposed_s3_prefix],
        status: product[:status],
        reason: reason
      }
    end

    def build_summary(audit, packaged_products, skipped_products)
      {
        scanned_products: audit.summary[:scanned_products],
        ready_products: audit.summary[:ready_products],
        packaged_products: packaged_products.size,
        skipped_products: skipped_products.size,
        issue_count: audit.summary[:issue_count]
      }
    end
  end
end
