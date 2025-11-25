class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items, dependent: :destroy
  has_one :payment, dependent: :destroy

  validates :user_id, presence: true
  validates :total, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending completed failed cancelled] }
  validates :stripe_session_id, uniqueness: true, allow_nil: true

  def self.ransackable_associations(auth_object = nil)
    ["order_items", "payment", "user"]
  end
  
  def self.ransackable_attributes(auth_object = nil)
    ["id", "total", "status", "created_at", "updated_at", "shipping_address", "user_id"]
  end
end
