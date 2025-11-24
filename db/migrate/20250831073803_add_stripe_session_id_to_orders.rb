class AddStripeSessionIdToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :stripe_session_id, :string
    add_index :orders, :stripe_session_id
  end
end
