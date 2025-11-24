class DownloadsController < ApplicationController
  before_action :authenticate_user!

  def show
    # Find the download access by token
    @download_access = DownloadAccess.find_by!(access_token: params[:token])

    # Check if expired
    if @download_access.expired?
      redirect_to root_path, alert: 'Download link has expired'
      return
    end

    # Check if current user owns this download
    if @download_access.user != current_user
      redirect_to root_path, alert: 'Unauthorized access'
      return
    end

    # Increment download count
    @download_access.increment!(:download_count)

    # Serve the file
    if @download_access.product&.embroidery_file&.attached?
      # Generate signed URL for S3
      redirect_to rails_blob_url(@download_access.product.embroidery_file, disposition: "attachment", only_path: false)
    else
      redirect_to root_path, alert: 'File not available'
    end
  end
end


