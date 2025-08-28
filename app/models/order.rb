class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items
  has_one :payment
  
  def self.ransackable_associations(auth_object = nil)
    ["order_items", "payment", "user"]
  end
  
  def self.ransackable_attributes(auth_object = nil)
    ["id", "total", "status", "created_at", "updated_at", "shipping_address", "user_id"]
  end
end
