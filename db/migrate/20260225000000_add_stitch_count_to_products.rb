class AddStitchCountToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :stitch_count, :integer
  end
end
