class AddShippableToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :shippable, :boolean, default: false, null: false
  end
end
