require "base64"

namespace :embroidery_catalog do
  desc "Import products directly from S3 bucket when local source files are unavailable"
  task import_from_s3: :environment do
    require "aws-sdk-s3"

    bucket            = "shopzilla-prod-assets-na"
    images_prefix     = "products/images/"
    embroidery_prefix = "downloads/embroidery/"
    service_name      = "amazon"

    s3 = Aws::S3::Client.new(region: "us-east-2")

    category_map = {
      "alesandro" => "Monograms",
      "animals"   => "Animal Patterns",
    }.freeze

    def self.titleize(slug)
      slug.split("-").map(&:capitalize).join(" ")
    end

    def self.adopt_blob(s3, bucket, key, filename, byte_size, content_type, service_name)
      existing = ActiveStorage::Blob.find_by(key: key)
      return existing if existing

      etag     = s3.head_object(bucket: bucket, key: key).etag.delete('"')
      checksum = Base64.strict_encode64([etag].pack("H*")) rescue SecureRandom.base64(28)

      ActiveStorage::Blob.create!(
        key:          key,
        filename:     filename,
        byte_size:    byte_size,
        content_type: content_type,
        service_name: service_name,
        checksum:     checksum
      )
    end

    puts "Scanning s3://#{bucket}/ ..."

    image_map = Hash.new { |h, k| h[k] = [] }
    s3.list_objects_v2(bucket: bucket, prefix: images_prefix).each_page do |page|
      page.contents.each do |obj|
        next unless obj.key.match?(/\.(png|jpg|webp)$/i)
        rel   = obj.key.delete_prefix(images_prefix)
        parts = rel.split("/")
        next unless parts.size == 4
        image_map[parts[0, 3].join("/")] << obj
      end
    end

    emb_map = {}
    s3.list_objects_v2(bucket: bucket, prefix: embroidery_prefix).each_page do |page|
      page.contents.each do |obj|
        next unless obj.key.match?(/\.(pes|dst|jef|exp|vp3)$/i)
        rel   = obj.key.delete_prefix(embroidery_prefix)
        parts = rel.split("/")
        next unless parts.size == 4
        emb_map[parts[0, 3].join("/")] ||= obj
      end
    end

    puts "Found #{image_map.size} products."

    created = 0
    skipped = 0
    errors  = 0

    image_map.each do |product_key, image_objs|
      cat_slug, design_slug, size_slug = product_key.split("/")

      cat_name     = category_map[cat_slug] || titleize(cat_slug)
      design_title = titleize(design_slug)
      dimensions   = size_slug.upcase

      begin
        category = Category.find_or_create_by!(name: cat_name)
        product  = Product.find_or_initialize_by(title: design_title, category: category)

        if product.persisted?
          skipped += 1
          next
        end

        emb_obj = emb_map[product_key]
        ext     = emb_obj ? File.extname(emb_obj.key).delete_prefix(".").upcase : "PES"

        product.assign_attributes(
          price:            5.00,
          dimensions:       dimensions,
          is_available:     true,
          physical_product: false,
          shippable:        false,
          file_format:      ext
        )
        product.save!

        image_objs.sort_by(&:key).first(2).each do |img|
          fname = File.basename(img.key)
          blob  = adopt_blob(s3, bucket, img.key, fname, img.size, "image/png", service_name)
          product.images.attach(blob)
        end

        if emb_obj
          fname = File.basename(emb_obj.key)
          blob  = adopt_blob(s3, bucket, emb_obj.key, fname, emb_obj.size, "application/octet-stream", service_name)
          product.embroidery_file.attach(blob)
        end

        created += 1
        puts "  + #{design_title} (#{dimensions}) [#{cat_name}]"
      rescue => e
        errors += 1
        warn "ERROR #{product_key}: #{e.message}"
      end
    end

    puts "\nDone. Created: #{created} | Skipped: #{skipped} | Errors: #{errors}"
    puts "Total products in DB: #{Product.count}"
  end
end
