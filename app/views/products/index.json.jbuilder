json.products do
  json.array! @products do |product|
    json.partial! "products/product", product: product
  end
end

json.meta do
  json.current_page @products.current_page
  json.total_pages  @products.total_pages
  json.total_count  @products.total_count
  json.per_page     @products.limit_value
end
