class AddFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :description, :text
    add_column :products, :category, :string
    add_column :products, :file_format, :string
    add_column :products, :is_available, :boolean
    add_column :products, :dimensions, :string
  end
end
