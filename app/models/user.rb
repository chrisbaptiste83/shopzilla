class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :orders, dependent: :restrict_with_exception
  has_one_attached :avatar
  has_rich_text :bio

  has_many :download_accesses, dependent: :destroy
  

  def self.ransackable_associations(auth_object = nil)
    ["orders"]
  end
  
  def self.ransackable_attributes(auth_object = nil)
    ["id", "email", "created_at", "updated_at", "admin"]
  end
end
