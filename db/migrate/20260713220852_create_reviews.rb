class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :rating, null: false, default: 5
      t.text :content

      t.timestamps
    end

    add_index :reviews, [:product_id, :user_id], unique: true
  end
end
