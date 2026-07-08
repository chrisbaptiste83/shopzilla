# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
require "yaml"
require "json"

catalog = YAML.load_file(Rails.root.join("db/seeds/catalog.yml"))

catalog.fetch("categories", []).each do |name|
  Category.find_or_create_by!(name: name)
end

if Rails.env.development?
  puts "Seeding products from catalog..."
  Rake::Task["embroidery:import"].invoke
elsif Rails.env.production? && Product.count.zero?
  puts "Production: loading pre-rendered product data..."

  data_file = Rails.root.join("db/seeds/production_data.json")
  data = JSON.parse(File.read(data_file))

  cat_id_map = {}
  data["categories"].each do |c|
    cat = Category.find_or_create_by!(name: c["name"])
    cat_id_map[c["id"]] = cat.id
  end

  product_id_map = {}
  data["products"].each do |p|
    product = Product.find_or_initialize_by(title: p["title"])
    product.category_id    = cat_id_map.fetch(p["category_id"])
    product.price          = p["price"]
    product.stitch_count   = p["stitch_count"]
    product.file_format    = p["file_format"]
    product.is_available   = p["is_available"]
    product.physical_product = p["physical_product"]
    product.shippable      = p["shippable"]
    product.description    = p["description"] if product.description.blank?
    product.save!
    product_id_map[p["id"]] = product.id
  end

  data["blobs"].each do |b|
    next if ActiveStorage::Blob.exists?(key: b["key"])
    ActiveStorage::Blob.create!(
      key:          b["key"],
      filename:     b["filename"],
      content_type: b["content_type"],
      byte_size:    b["byte_size"],
      checksum:     b["checksum"],
      service_name: b["service_name"],
      created_at:   b["created_at"]
    )
  end

  data["attachments"].each do |a|
    blob = ActiveStorage::Blob.find_by!(key: data["blobs"].find { |b| b["id"] == a["blob_id"] }&.fetch("key"))
    new_record_id = product_id_map[a["record_id"]]
    next unless new_record_id
    next if ActiveStorage::Attachment.exists?(name: a["name"], record_type: a["record_type"], record_id: new_record_id, blob_id: blob.id)
    ActiveStorage::Attachment.create!(
      name:        a["name"],
      record_type: a["record_type"],
      record_id:   new_record_id,
      blob_id:     blob.id,
      created_at:  a["created_at"]
    )
  end

  puts "Production seed complete: #{Product.count} products, #{ActiveStorage::Attachment.where(record_type: 'Product').count} attachments"
end
