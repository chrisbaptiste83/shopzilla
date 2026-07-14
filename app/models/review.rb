class Review < ApplicationRecord
  belongs_to :product
  belongs_to :user

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :user_id, uniqueness: { scope: :product_id, message: "has already reviewed this product" }
end
