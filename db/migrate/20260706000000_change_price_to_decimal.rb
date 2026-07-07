class ChangePriceToDecimal < ActiveRecord::Migration[8.0]
  def up
    change_column :products, :price, :decimal, precision: 10, scale: 2
  end

  def down
    change_column :products, :price, :integer
  end
end
