class Product < ApplicationRecord
  # Add a virtual attribute to hold the new category name
  attr_accessor :new_category_name

  has_rich_text :description
  has_one_attached :embroidery_file
  has_many_attached :images
  belongs_to :category
  has_many :download_accesses, dependent: :destroy
  has_many :wishlist_items, dependent: :destroy

  before_validation :create_category_from_name, if: -> { new_category_name.present? }

  validates :title, presence: true, length: { minimum: 3, maximum: 255 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :category_id, presence: true, unless: -> { new_category_name.present? }
  validate :acceptable_images
  validate :acceptable_embroidery_file

  def self.ransackable_attributes(auth_object = nil)
    %w[id title price file_format is_available dimensions stitch_count created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[category]
  end

  private

  def create_category_from_name
    created_category = Category.create!(name: new_category_name)
    self.category_id = created_category.id
  end

  EMBROIDERY_EXTENSIONS = %w[.pes .dst .jef .exp .vp3 .hus .pcs .xxx .sew .shv .csd .emd].freeze

  def acceptable_images
    return unless images.attached?

    if images.count > 10
      errors.add(:images, "maximum of 10 images allowed per product")
    end

    images.each do |image|
      unless image.content_type.start_with?("image/")
        errors.add(:images, "must be an image file")
      end

      if image.byte_size > 10.megabytes
        errors.add(:images, "must be less than 10MB")
      end
    end
  end

  def acceptable_embroidery_file
    return unless embroidery_file.attached?

    ext = File.extname(embroidery_file.filename.to_s).downcase
    unless EMBROIDERY_EXTENSIONS.include?(ext)
      errors.add(:embroidery_file, "must be a supported embroidery format (#{EMBROIDERY_EXTENSIONS.join(', ')})")
    end

    if embroidery_file.byte_size > 25.megabytes
      errors.add(:embroidery_file, "must be less than 25MB")
    end
  end
end
