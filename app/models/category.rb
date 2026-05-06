class Category < ApplicationRecord
  has_many :products, dependent: :restrict_with_exception

  scope :with_available_products, -> {
    joins(:products).where(products: { is_available: true }).distinct.order(:name)
  }

  def self.ransackable_attributes(auth_object = nil)
    %w[id name description created_at updated_at]
  end
end
