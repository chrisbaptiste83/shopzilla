class AddIndexesToOmniauthAndStripe < ActiveRecord::Migration[8.0]
  def change
    add_index :users, [:provider, :uid], unique: true
    add_index :payments, :stripe_payment_id
  end
end