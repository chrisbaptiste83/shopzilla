class Category < ApplicationRecord
  has_many :products, dependent: :restrict_with_exception


  def self.ransackable_attributes(auth_object = nil)
    %w[id name description created_at updated_at]
  end
end
