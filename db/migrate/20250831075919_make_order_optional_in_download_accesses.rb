class MakeOrderOptionalInDownloadAccesses < ActiveRecord::Migration[8.0]
  def change
    change_column_null :download_accesses, :order_id, true
  end
end

