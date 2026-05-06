class AddDescriptionToCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :description, :text unless column_exists?(:categories, :description)
  end
end
