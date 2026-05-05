require "json"

module Embroidery
  class S3Uploader
    CONTENT_TYPES = {
      ".pes" => "application/octet-stream",
      ".dst" => "application/octet-stream",
      ".jef" => "application/octet-stream",
      ".exp" => "application/octet-stream",
      ".vp3" => "application/octet-stream",
      ".hus" => "application/octet-stream",
      ".xxx" => "application/octet-stream",
      ".png"  => "image/png",
      ".jpg"  => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".webp" => "image/webp",
      ".json" => "application/json"
    }.freeze

    UploadedFile = Struct.new(:s3_key, :byte_size, :content_type, :dry_run, keyword_init: true)
    SkippedFile  = Struct.new(:s3_key, :reason, keyword_init: true)
    FailedFile   = Struct.new(:s3_key, :error, keyword_init: true)

    Result = Struct.new(
      :manifest_path,
      :bucket,
      :uploaded,
      :skipped,
      :errors,
      :summary,
      keyword_init: true
    ) do
      def to_h
        {
          manifest_path: manifest_path,
          bucket: bucket,
          summary: summary,
          uploaded: uploaded.map(&:to_h),
          skipped: skipped.map(&:to_h),
          errors: errors.map(&:to_h)
        }
      end
    end

    def initialize(manifest_path:, bucket: nil, region: nil, dry_run: true, overwrite: false)
      @manifest_path = Pathname.new(manifest_path).expand_path
      @bucket = bucket || rails_s3_bucket
      @region = region || rails_s3_region
      @dry_run = dry_run
      @overwrite = overwrite
    end

    def call
      raise ArgumentError, "manifest path does not exist: #{@manifest_path}" unless @manifest_path.file?

      manifest = JSON.parse(@manifest_path.read).deep_symbolize_keys
      package_root = @manifest_path.dirname
      packaged_products = Array(manifest[:packaged_products])

      uploaded = []
      skipped  = []
      errors   = []

      packaged_products.each do |product|
        collect_product_files(product, package_root).each do |local_path, s3_key|
          upload_one(local_path, s3_key, uploaded, skipped, errors)
        end
      end

      result = Result.new(
        manifest_path: @manifest_path.to_s,
        bucket: @bucket,
        uploaded: uploaded,
        skipped: skipped,
        errors: errors,
        summary: build_summary(uploaded, skipped, errors)
      )

      report_path = @manifest_path.dirname.join("upload_report.json")
      File.write(report_path, JSON.pretty_generate(result.to_h))
      result
    end

    private

    def collect_product_files(product, package_root)
      files = {}

      Array(product[:embroidery_files]).each do |f|
        files[package_root.join(f[:proposed_s3_key])] = f[:proposed_s3_key]
      end

      Array(product[:preview_images]).each do |f|
        files[package_root.join(f[:proposed_s3_key])] = f[:proposed_s3_key]
      end

      metadata_key = product[:proposed_metadata_key]
      if metadata_key.present?
        local = package_root.join(metadata_key)
        files[local] = metadata_key if local.file?
      end

      files
    end

    def upload_one(local_path, s3_key, uploaded, skipped, errors)
      unless local_path.file?
        errors << FailedFile.new(s3_key: s3_key, error: "local file not found: #{local_path}")
        return
      end

      content_type = content_type_for(local_path)
      byte_size    = local_path.size

      if @dry_run
        uploaded << UploadedFile.new(s3_key: s3_key, byte_size: byte_size, content_type: content_type, dry_run: true)
        return
      end

      unless @overwrite
        begin
          s3_client.head_object(bucket: @bucket, key: s3_key)
          skipped << SkippedFile.new(s3_key: s3_key, reason: "already_exists")
          return
        rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
          # object does not exist — proceed with upload
        end
      end

      local_path.open("rb") do |io|
        s3_client.put_object(
          bucket: @bucket,
          key: s3_key,
          body: io,
          content_type: content_type,
          content_length: byte_size,
          server_side_encryption: "AES256"
        )
      end

      uploaded << UploadedFile.new(s3_key: s3_key, byte_size: byte_size, content_type: content_type, dry_run: false)
    rescue Aws::S3::Errors::ServiceError => error
      errors << FailedFile.new(s3_key: s3_key, error: error.message)
    end

    def s3_client
      @s3_client ||= begin
        key_id  = Rails.application.credentials.dig(:aws, :access_key_id)    rescue nil
        secret  = Rails.application.credentials.dig(:aws, :secret_access_key) rescue nil

        opts = { region: @region }
        opts[:access_key_id]     = key_id  if key_id.present?
        opts[:secret_access_key] = secret  if secret.present?
        # When Rails credentials are absent, the SDK falls through to the default
        # provider chain: ENV vars → ~/.aws/credentials → IAM instance profile.
        Aws::S3::Client.new(**opts)
      end
    end

    def storage_yml
      @storage_yml ||= YAML.safe_load(File.read(Rails.root.join("config/storage.yml"))) || {}
    end

    def rails_s3_bucket
      storage_yml.dig("amazon", "bucket") ||
        raise(ArgumentError, "S3 bucket not configured in config/storage.yml — pass S3_BUCKET= explicitly")
    end

    def rails_s3_region
      storage_yml.dig("amazon", "region") || "us-east-1"
    end

    def content_type_for(path)
      CONTENT_TYPES.fetch(path.extname.downcase, "application/octet-stream")
    end

    def build_summary(uploaded, skipped, errors)
      total_bytes = uploaded.sum(&:byte_size)
      {
        dry_run: @dry_run,
        uploaded_count: uploaded.size,
        skipped_count: skipped.size,
        error_count: errors.size,
        total_bytes: total_bytes,
        total_mb: (total_bytes.to_f / 1.megabyte).round(2)
      }
    end
  end
end
