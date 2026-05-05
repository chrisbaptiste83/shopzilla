namespace :active_storage do
  namespace :s3 do
    desc "Copy ActiveStorage blobs from local disk to S3; DRY_RUN=1 to preview"
    task migrate: :environment do
      dry_run    = ENV["DRY_RUN"].in?(%w[1 true yes])
      start_id   = ENV.fetch("START_ID", "0").to_i
      limit      = ENV["LIMIT"]&.to_i

      local_service = ActiveStorage::Blob.service
      s3_service    = ActiveStorage::Service.configure(:amazon, Rails.configuration.active_storage.service_configurations)

      scope = ActiveStorage::Blob.where("id > ?", start_id).order(:id)
      scope = scope.limit(limit) if limit

      total   = scope.count
      copied  = 0
      skipped = 0
      errors  = 0

      puts "ActiveStorage → S3 migration #{dry_run ? '(DRY RUN) ' : ''}| blobs: #{total}"

      scope.find_each do |blob|
        key = blob.key

        if s3_service.exist?(key)
          skipped += 1
          next
        end

        unless local_service.exist?(key)
          puts "  MISSING local blob #{key} (id=#{blob.id})"
          errors += 1
          next
        end

        unless dry_run
          local_service.open(key, checksum: blob.checksum) do |tmpfile|
            s3_service.upload(key, tmpfile, checksum: blob.checksum, content_type: blob.content_type)
          end
        end

        copied += 1
        print "." if (copied % 50).zero?
      rescue => error
        puts "\n  ERROR blob #{key} (id=#{blob.id}): #{error.message}"
        errors += 1
        raise if errors > 10
      end

      puts "\nDone. copied=#{copied} skipped=#{skipped} errors=#{errors}"
      raise "Migration finished with #{errors} error(s)" if errors > 0
    end

    desc "Verify every ActiveStorage blob exists in S3; exits non-zero if any are missing"
    task verify: :environment do
      start_id = ENV.fetch("START_ID", "0").to_i
      limit    = ENV["LIMIT"]&.to_i

      s3_service = ActiveStorage::Service.configure(:amazon, Rails.configuration.active_storage.service_configurations)

      scope = ActiveStorage::Blob.where("id > ?", start_id).order(:id)
      scope = scope.limit(limit) if limit

      total   = scope.count
      missing = 0

      puts "ActiveStorage S3 verify | blobs: #{total}"

      scope.find_each do |blob|
        unless s3_service.exist?(blob.key)
          puts "  MISSING #{blob.key} (id=#{blob.id}, filename=#{blob.filename})"
          missing += 1
        end
      end

      puts "Done. missing=#{missing}"
      raise "Verify failed: #{missing} blob(s) not found in S3" if missing > 0
    end
  end
end
