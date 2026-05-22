class AddIndexToPaymentsOrderId < ActiveRecord::Migration[8.0]
  def change
    add_index :payments, :order_id
  end
end
