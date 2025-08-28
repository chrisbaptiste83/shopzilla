class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  has_many :orders, dependent: :destroy
  has_one_attached :avatar
  has_rich_text :bio
  
  validates :email, presence: true, uniqueness: true
  
  def full_name
    email.split('@').first.gsub('.', ' ').humanize
  end
  
  def total_orders
    orders.count
  end
  
  def total_spent
    orders.joins(:order_items).sum('order_items.quantity * order_items.unit_price')
  end
end
