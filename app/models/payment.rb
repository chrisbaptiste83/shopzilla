class Payment < ApplicationRecord
  belongs_to :order

  validates :order_id, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending completed failed] }

  def self.ransackable_associations(auth_object = nil)
    ["order"]
  end
  
  def self.ransackable_attributes(auth_object = nil)
    ["id", "amount", "stripe_payment_id", "status", "created_at", "updated_at", "order_id"]
  end
end
