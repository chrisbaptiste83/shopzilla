class AddUniqueIndexToDownloadAccessesToken < ActiveRecord::Migration[8.0]
  def change
    add_index :download_accesses, :access_token, unique: true, if_not_exists: true
  end
end
