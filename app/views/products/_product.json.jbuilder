json.extract! product, :id, :title, :price, :file_format, :is_available,
                          :dimensions, :stitch_count, :physical_product,
                          :shippable, :created_at, :updated_at

json.description  product.description.to_plain_text

json.category do
  if product.category
    json.id   product.category.id
    json.name product.category.name
  else
    json.nil!
  end
end

json.images do
  if product.images.attached?
    json.array! product.images do |image|
      json.url     url_for(image)
      json.filename image.filename.to_s
    end
  else
    json.array! []
  end
end

json.url product_url(product, format: :json)
