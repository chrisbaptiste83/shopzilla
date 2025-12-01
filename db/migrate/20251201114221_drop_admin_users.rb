class DropAdminUsers < ActiveRecord::Migration[8.0]
  def change
    drop_table :admin_users do |t|
      t.string :email, default: "", null: false
      t.string :encrypted_password, default: "", null: false
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index :email, unique: true
      t.index :reset_password_token, unique: true
    end

    drop_table :active_admin_comments do |t|
      t.string :namespace
      t.text :body
      t.string :resource_type
      t.integer :resource_id
      t.string :author_type
      t.integer :author_id
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index [:author_type, :author_id]
      t.index :namespace
      t.index [:resource_type, :resource_id]
    end
  end
end
