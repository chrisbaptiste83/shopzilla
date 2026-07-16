class CreateWebauthnCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :webauthn_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id
      t.string :public_key
      t.integer :sign_count

      t.timestamps
    end
  end
end
