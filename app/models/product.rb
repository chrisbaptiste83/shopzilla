class Product < ApplicationRecord
  # Add a virtual attribute to hold the new category name
  attr_accessor :new_category_name

  has_rich_text :description
  has_one_attached :embroidery_file
  has_many_attached :images
  belongs_to :category
  has_many :wishlist_items, dependent: :destroy

  before_save :create_category_from_name, if: -> { new_category_name.present? }

  validates :title, presence: true, length: { minimum: 3, maximum: 255 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :category_id, presence: true, unless: -> { new_category_name.present? }
  validate :acceptable_images

  def self.ransackable_attributes(auth_object = nil)
    %w[id title price file_format is_available dimensions created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[category]
  end

  private

  def create_category_from_name
    created_category = Category.create!(name: new_category_name)
    self.category_id = created_category.id
  end

  def acceptable_images
    return unless images.attached?

    images.each do |image|
      unless image.content_type.start_with?('image/')
        errors.add(:images, 'must be an image file')
      end

      if image.byte_size > 10.megabytes
        errors.add(:images, 'must be less than 10MB')
      end
    end
  end

end
