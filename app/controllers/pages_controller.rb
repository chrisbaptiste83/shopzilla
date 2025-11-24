class PagesController < ApplicationController
  before_action :authenticate_user!, only: [:success]

  def success
    return @download_accesses = [] unless current_user && params[:session_id].present?

    # Fetch the Stripe session
    session_id = params[:session_id]
    stripe_session = Stripe::Checkout::Session.retrieve(session_id)

    # Retrieve line items from Stripe
    line_items = Stripe::Checkout::Session.list_line_items(session_id)

    # For each purchased product, create a DownloadAccess if it doesn't exist
    @download_accesses = line_items.data.map do |item|
      # Match product by name or your own metadata (better to pass product_id in metadata)
      product = Product.find_by(title: item.description) # or item.metadata['product_id'] if set

      next unless product

      DownloadAccess.find_or_create_by!(
        user: current_user,
        product: product,
        order: nil # attach the order if you want
      ) do |da|
        da.expires_at = 30.days.from_now
        da.download_count = 0
        da.access_token = SecureRandom.urlsafe_base64(32)
      end
    end.compact

    # Optional: order by creation
    @download_accesses.sort_by!(&:created_at).reverse!
  rescue Stripe::StripeError => e
    # Handle invalid session
    @download_accesses = []
    flash.now[:alert] = "Could not retrieve purchase details: #{e.message}"
  end

  def cancel
    # optional
  end
end

