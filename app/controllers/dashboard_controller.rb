class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @recent_orders = current_user.orders.order(created_at: :desc).limit(5).includes(order_items: { product: [:images_attachments] })
    @download_count = current_user.download_accesses.where("expires_at > ?", Time.current).count
    @wishlist_count = current_user.wishlist_items.count
    @total_spent = current_user.orders.where(status: "completed").sum(:total)
    @total_orders = current_user.orders.where(status: "completed").count
  end

  def orders
    @orders = current_user.orders.order(created_at: :desc).includes(order_items: { product: [:images_attachments, :category] })
  end

  def downloads
    @download_accesses = current_user.download_accesses.where("expires_at > ?", Time.current).includes(product: [:images_attachments, :category, :embroidery_file_attachment]).order(created_at: :desc)
  end

  def wishlist
    @wishlist_items = current_user.wishlist_items.includes(product: [:images_attachments, :category]).order(created_at: :desc)
  end
end
