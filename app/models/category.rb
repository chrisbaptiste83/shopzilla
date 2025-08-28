class Category < ApplicationRecord
  validates :name, presence: true, uniqueness: true, length: { minimum: 2, maximum: 50 }

  scope :with_products, -> { where(name: Product.distinct.pluck(:category).compact) }
  scope :alphabetical, -> { order(:name) }

  def products
    Product.where(category: name)
  end

  def products_count
    Product.where(category: name).count
  end

  def display_name
    name.titleize
  end
end
