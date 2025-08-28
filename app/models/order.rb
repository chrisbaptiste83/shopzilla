class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items, dependent: :destroy
  has_one :payment, dependent: :destroy
  
  validates :total, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending paid shipped completed cancelled] }
  validates :shipping_address, presence: true
  
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :recent, -> { order(created_at: :desc) }
  
  before_validation :calculate_total, if: :order_items_changed?
  
  def calculate_total
    self.total = order_items.sum { |item| item.quantity * item.unit_price }
    self.total
  end
  
  def formatted_total
    "$#{'%.2f' % total}"
  end
  
  def status_badge_class
    case status
    when 'pending' then 'badge-warning'
    when 'paid' then 'badge-info'
    when 'shipped' then 'badge-primary'
    when 'completed' then 'badge-success'
    when 'cancelled' then 'badge-error'
    else 'badge-ghost'
    end
  end
  
  private
  
  def order_items_changed?
    order_items.any?(&:changed?)
  end
end
