class DownloadsController < ApplicationController
  before_action :authenticate_user!
  
  def show
    @download_access = DownloadAccess.find_by!(access_token: params[:token])
    
    if @download_access.expired?
      redirect_to root_path, alert: 'Download link has expired'
      return
    end
    
    if @download_access.user != current_user
      redirect_to root_path, alert: 'Unauthorized access'
      return
    end
    
    @download_access.increment!(:download_count)
    
    # Generate signed URL for S3 download
    if @download_access.product.embroidery_file.attached?
      redirect_to @download_access.product.embroidery_file.url(expires_in: 1.hour)
    else
      redirect_to root_path, alert: 'File not available'
    end
  end
end
