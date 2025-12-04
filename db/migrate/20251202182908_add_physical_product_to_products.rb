class AddPhysicalProductToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :physical_product, :boolean
  end
end
