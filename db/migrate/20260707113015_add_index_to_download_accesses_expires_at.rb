class AddIndexToDownloadAccessesExpiresAt < ActiveRecord::Migration[8.0]
  def change
    add_index :download_accesses, :expires_at
  end
end
