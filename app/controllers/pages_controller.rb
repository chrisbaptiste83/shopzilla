class PagesController < ApplicationController
  before_action :authenticate_user!, only: [ :success ]

  def success
    return @download_accesses = [] unless current_user && params[:session_id].present?

    order = current_user.orders.find_by(stripe_session_id: params[:session_id])
    return @download_accesses = [] unless order

    @download_accesses = current_user.download_accesses
                                     .active
                                     .includes(product: :embroidery_file_attachment)
                                     .where(order: order)
                                     .order(created_at: :desc)
  end

  def cancel
    # optional
  end
end
