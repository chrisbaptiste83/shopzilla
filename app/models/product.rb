class Product < ApplicationRecord
  has_rich_text :description
  has_one_attached :embroidery_file
  has_many_attached :images
  belongs_to :category


   def self.ransackable_attributes(auth_object = nil)
    %w[id title price file_format is_available dimensions created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[category]
  end

end
