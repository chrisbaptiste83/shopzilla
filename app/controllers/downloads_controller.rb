class DownloadsController < ApplicationController
  before_action :authenticate_user!

  MAX_DOWNLOADS = 10

  def show
    @download_access = DownloadAccess.find_by!(access_token: params[:token])

    if @download_access.expired?
      redirect_to root_path, alert: "Download link has expired"
      return
    end

    if @download_access.user != current_user
      redirect_to root_path, alert: "Unauthorized access"
      return
    end

    if @download_access.download_count >= MAX_DOWNLOADS
      redirect_to root_path, alert: "Download limit reached. Please contact support."
      return
    end

    @download_access.increment!(:download_count)

    if @download_access.product&.embroidery_file&.attached?
      redirect_to rails_blob_url(@download_access.product.embroidery_file, disposition: "attachment", only_path: false)
    else
      redirect_to root_path, alert: "File not available"
    end
  end
end
