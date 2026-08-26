namespace :storage do
  desc "Reconcile Active Storage blob checksums with their configured storage service (DRY_RUN=true by default)"
  task reconcile_blob_checksums: :environment do
    require "base64"
    require "digest"

    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
    scope = ActiveStorage::Blob.where.not(service_name: "test")
    scope = scope.where(content_type: ENV["CONTENT_TYPE"]) if ENV["CONTENT_TYPE"].present?
    if ActiveModel::Type::Boolean.new.cast(ENV.fetch("PRODUCT_IMAGES", "false"))
      scope = scope.joins(:attachments)
        .where(active_storage_attachments: { record_type: "Product", name: "images" })
        .distinct
    end

    checked = 0
    updated = 0
    errors = []

    scope.find_each do |blob|
      checked += 1
      contents = blob.service.download(blob.key)
      checksum = Base64.strict_encode64(Digest::MD5.digest(contents))
      byte_size = contents.bytesize

      next if blob.checksum == checksum && blob.byte_size == byte_size

      puts "#{dry_run ? 'Would update' : 'Updated'} blob #{blob.id} (#{blob.filename})"
      puts "  checksum: #{blob.checksum} -> #{checksum}" if blob.checksum != checksum
      puts "  byte size: #{blob.byte_size} -> #{byte_size}" if blob.byte_size != byte_size

      unless dry_run
        blob.update!(checksum: checksum, byte_size: byte_size)
        updated += 1
      end
    rescue StandardError => error
      errors << "blob #{blob.id} (#{blob.filename}): #{error.message}"
    end

    errors.each { |error| warn "ERROR: #{error}" }
    puts "Checked #{checked} blob(s); #{dry_run ? 'would update' : 'updated'} #{updated} blob(s); errors=#{errors.size}."
    raise "Checksum reconciliation failed for #{errors.size} blob(s)" if errors.any?
  end

  desc "Backfill explicit role/style metadata on Product preview images"
  task backfill_image_metadata: :environment do
    updated = 0

    Product.includes(images_attachments: :blob).find_each do |product|
      product.images.attachments.each do |attachment|
        blob = attachment.blob
        metadata = Product.image_metadata_for(filename: blob.filename.to_s)
        next if metadata.all? { |key, value| blob.metadata[key].to_s == value.to_s }

        blob.update!(metadata: blob.metadata.to_h.merge(metadata))
        updated += 1
      end
    end

    puts "Updated metadata on #{updated} Product image blob(s)."
  end

  desc "Purge all cached image variants and orphaned unattached blobs"
  task cleanup: :environment do
    # 1. Purge all variant records (resized/cached copies)
    variant_count = ActiveStorage::VariantRecord.count
    if variant_count > 0
      ActiveStorage::VariantRecord.find_each do |variant|
        variant.image.purge
      rescue => e
        puts "  Warning: could not purge variant #{variant.id}: #{e.message}"
      end
      puts "Purged #{variant_count} variant records"
    else
      puts "No variant records found"
    end

    # 2. Purge unattached blobs (orphaned originals not linked to any record)
    unattached = ActiveStorage::Blob.unattached
    unattached_count = unattached.count
    if unattached_count > 0
      unattached.find_each(&:purge)
      puts "Purged #{unattached_count} unattached blobs"
    else
      puts "No unattached blobs found"
    end

    puts "Done. Storage cleanup complete."
  end
end
