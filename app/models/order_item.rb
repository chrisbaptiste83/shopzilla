class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :unit_price, presence: true, numericality: { greater_than: 0 }

  before_validation :set_unit_price, if: :product_id_changed?

  def total_price
    quantity * unit_price
  end

  def formatted_total_price
    "$#{'%.2f' % total_price}"
  end

  def formatted_unit_price
    "$#{'%.2f' % unit_price}"
  end

  private

  def set_unit_price
    self.unit_price = product.price if product.present?
  end
end
