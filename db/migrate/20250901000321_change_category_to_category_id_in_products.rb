class ChangeCategoryToCategoryIdInProducts < ActiveRecord::Migration[7.1]
  def change
    # Remove old string column
    remove_column :products, :category, :string

    # Add reference to categories (allowing NULL for now)
    add_reference :products, :category, null: true, foreign_key: true
  end
end

