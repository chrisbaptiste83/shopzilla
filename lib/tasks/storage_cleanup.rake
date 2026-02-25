namespace :storage do
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
