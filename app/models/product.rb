class Product < ApplicationRecord
  has_rich_text :description
  has_one_attached :embroidery_file
  has_many_attached :images
end
