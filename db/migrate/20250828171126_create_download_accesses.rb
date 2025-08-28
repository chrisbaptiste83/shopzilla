class CreateDownloadAccesses < ActiveRecord::Migration[8.0]
  def change
    create_table :download_accesses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.string :access_token
      t.datetime :expires_at
      t.integer :download_count

      t.timestamps
    end
  end
end
