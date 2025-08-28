class Product < ApplicationRecord
  has_rich_text :description
  has_one_attached :embroidery_file
  has_many_attached :images

  validates :title, presence: true, length: { minimum: 3, maximum: 100 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :category, length: { maximum: 50 }, allow_blank: true
  validates :file_format, length: { maximum: 20 }, allow_blank: true
  validates :dimensions, length: { maximum: 50 }, allow_blank: true

  scope :available, -> { where(is_available: true) }
  scope :by_category, ->(category) { where(category: category) if category.present? }

  def formatted_price
    "$#{price}"
  end

  def display_category
    category.present? ? category.titleize : "Uncategorized"
  end
end
