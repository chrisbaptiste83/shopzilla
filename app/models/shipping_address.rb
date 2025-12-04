class ShippingAddress < ApplicationRecord
  belongs_to :order

  validates :full_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :street_address, presence: true, length: { minimum: 5, maximum: 200 }
  validates :city, presence: true, length: { minimum: 2, maximum: 100 }
  validates :state, presence: true, length: { minimum: 2, maximum: 50 }
  validates :zip_code, presence: true, format: { with: /\A\d{5}(-\d{4})?\z/, message: "must be a valid US ZIP code (e.g., 12345 or 12345-6789)" }
  validates :country, presence: true, length: { minimum: 2, maximum: 50 }
end
