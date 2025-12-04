class CreateShippingAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :shipping_addresses do |t|
      t.string :full_name
      t.string :street_address
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :country
      t.references :order, null: false, foreign_key: true

      t.timestamps
    end
  end
end
