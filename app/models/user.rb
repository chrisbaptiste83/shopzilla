class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :orders  
  has_one_attached :avatar
  has_rich_text :bio

end
