require "json"

module Embroidery
  class CatalogImporter
    Result = Struct.new(
      :manifest_path,
      :imported_products,
      :errors,
      :summary,
      keyword_init: true
    ) do
      def to_h
        {
          manifest_path: manifest_path,
          summary: summary,
          imported_products: imported_products,
          errors: errors
        }
      end
    end

    def initialize(manifest_path:, price_cents: 500, overwrite_attachments: true)
      @manifest_path = Pathname.new(manifest_path).expand_path
      @price_cents = price_cents.to_i
      @overwrite_attachments = overwrite_attachments
    end

    def call
      raise ArgumentError, "manifest path does not exist: #{@manifest_path}" unless @manifest_path.file?

      manifest = JSON.parse(@manifest_path.read).deep_symbolize_keys
      packaged_products = Array(manifest[:packaged_products])
      imported_products = []
      errors = []

      packaged_products.each do |entry|
        imported_products << import_product(entry)
      rescue StandardError => error
        errors << {
          source_relative_path: entry[:source_relative_path],
          proposed_s3_prefix: entry[:proposed_s3_prefix],
          error: error.message
        }
      end

      Result.new(
        manifest_path: @manifest_path.to_s,
        imported_products: imported_products,
        errors: errors,
        summary: build_summary(packaged_products, imported_products, errors)
      )
    end

    private

    def import_product(entry)
      category = Category.find_or_create_by!(name: entry.dig(:category, :label))
      record = Product.find_or_initialize_by(category: category, title: entry.dig(:design, :title))
      created = record.new_record?

      apply_attributes(record, entry)
      record.save!
      attach_files(record, entry)

      {
        product_id: record.id,
        source_relative_path: entry[:source_relative_path],
        proposed_s3_prefix: entry[:proposed_s3_prefix],
        status: created ? "created" : "updated"
      }
    end

    def apply_attributes(record, entry)
      record.price = @price_cents if record.price.blank? || record.price.to_i <= 0
      record.file_format = primary_file_extension(entry) if record.file_format.blank?
      record.dimensions = entry.dig(:size, :raw) if record.dimensions.blank?
      record.is_available = true if record.is_available.nil?
      record.physical_product = false if record.physical_product.nil?
      record.shippable = false if record.shippable.nil?
      record.stitch_count = entry.dig(:metadata, :stitch_count) if entry.dig(:metadata, :stitch_count).present?
      record.description = build_description(entry) if record.description.blank?
    end

    def attach_files(record, entry)
      embroidery_file = entry.fetch(:embroidery_files).first
      raise ArgumentError, "packaged product is missing an embroidery file" if embroidery_file.blank?

      replace_embroidery_attachment(record, embroidery_file)
      replace_preview_attachments(record, entry.fetch(:preview_images))
    end

    def replace_embroidery_attachment(record, file_entry)
      path = package_root.join(file_entry.fetch(:proposed_s3_key))
      raise ArgumentError, "missing packaged embroidery file: #{path}" unless path.file?

      destination_key = destination_key_for(file_entry, kind: :download)

      # Only purge the existing attachment when the S3 key is actually changing.
      # If the key is the same the file content hasn't changed — reuse the blob.
      if @overwrite_attachments && record.embroidery_file.attached?
        record.embroidery_file.purge if record.embroidery_file.blob.key != destination_key
      end

      blob = find_or_build_blob(path, file_entry, destination_key)
      record.embroidery_file.attach(blob) unless record.embroidery_file.blob&.key == destination_key
    end

    def replace_preview_attachments(record, files)
      return if files.blank?

      record.images.purge if @overwrite_attachments && record.images.attached?
      files.first(3).each do |file_entry|
        path = package_root.join(file_entry.fetch(:proposed_s3_key))
        raise ArgumentError, "missing packaged preview image: #{path}" unless path.file?

        blob = find_or_build_blob(path, file_entry, destination_key_for(file_entry, kind: :preview))
        metadata = Product.image_metadata_for(
          filename: file_entry.fetch(:filename),
          render_style: file_entry[:render_style]
        )
        blob.update!(metadata: blob.metadata.to_h.merge(metadata))
        record.images.attach(blob)
      end
    end

    def find_or_build_blob(path, file_entry, destination_key)
      existing = ActiveStorage::Blob.find_by(key: destination_key)
      return existing if existing.present?

      path.open("rb") do |io|
        ActiveStorage::Blob.create_and_upload!(
          key: destination_key,
          io: io,
          filename: file_entry.fetch(:filename),
          content_type: Marcel::MimeType.for(path, name: file_entry.fetch(:filename))
        )
      end
    end

    def destination_key_for(file_entry, kind:)
      original_key = file_entry.fetch(:proposed_s3_key)

      case kind
      when :download
        original_key
          .sub(/\Aembroidery\//, "downloads/embroidery/")
          .sub(%r{/download/}, "/")
      when :preview
        original_key
          .sub(/\Aembroidery\//, "products/images/")
          .sub(%r{/preview/}, "/")
      else
        raise ArgumentError, "unsupported destination kind: #{kind}"
      end
    end

    def build_description(entry)
      design_name    = entry.dig(:design, :normalized)
      category_label = entry.dig(:category, :label)
      size_label     = entry.dig(:size, :label)
      stitch_count   = entry.dig(:metadata, :stitch_count)

      lines = []

      if design_name.present? && size_label.present?
        lines << "#{design_name.capitalize} embroidery design, available in #{size_label}."
      elsif design_name.present?
        lines << "#{design_name.capitalize} embroidery design."
      end

      if stitch_count.present?
        formatted = ActiveSupport::NumberHelper.number_to_delimited(stitch_count)
        lines << "Features #{formatted} stitches for a detailed, professional finish."
      end

      lines << "Part of the #{category_label} collection." if category_label.present?
      lines << "Works with most home and commercial embroidery machines. Instant digital download included."

      lines.join(" ").presence
    end

    def primary_file_extension(entry)
      filename = entry.fetch(:embroidery_files).first.fetch(:filename)
      File.extname(filename).delete_prefix(".").upcase
    end

    def package_root
      @package_root ||= @manifest_path.dirname
    end

    def build_summary(packaged_products, imported_products, errors)
      {
        packaged_products: packaged_products.size,
        imported_products: imported_products.size,
        created_products: imported_products.count { |entry| entry[:status] == "created" },
        updated_products: imported_products.count { |entry| entry[:status] == "updated" },
        error_count: errors.size
      }
    end
  end
end
