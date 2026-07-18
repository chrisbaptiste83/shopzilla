# frozen_string_literal: true
class AddShopCommerceIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :products, [:category_id, :created_at], name: "index_products_on_category_id_and_created_at", if_not_exists: true
    add_index :orders, [:user_id, :status], name: "index_orders_on_user_id_and_status", if_not_exists: true
    add_index :orders, :stripe_session_id, name: "index_orders_on_stripe_session_id", if_not_exists: true
    add_index :payments, :stripe_payment_id, name: "index_payments_on_stripe_payment_id", if_not_exists: true
    add_index :download_accesses, [:user_id, :product_id], name: "index_download_accesses_on_user_id_and_product_id", if_not_exists: true
  end
end
