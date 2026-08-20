namespace :storage do
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
