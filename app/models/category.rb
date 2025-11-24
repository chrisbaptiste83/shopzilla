class Category < ApplicationRecord
  has_many :products


   def self.ransackable_attributes(auth_object = nil)
    %w[id name created_at updated_at]
  end

end
