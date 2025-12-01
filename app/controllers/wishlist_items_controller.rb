class WishlistItemsController < ApplicationController
  before_action :authenticate_user!

  def index
    @wishlist_items = current_user.wishlist_items.includes(product: [:category, :rich_text_description, { images_attachments: :blob }]).order(created_at: :desc)
  end

  def create
    @product = Product.find(params[:product_id])
    @wishlist_item = current_user.wishlist_items.build(product: @product)

    if @wishlist_item.save
      respond_to do |format|
        format.html { redirect_to @product, notice: "Product added to your wishlist!" }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to @product, alert: "Could not add to wishlist." }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { message: "Already in wishlist", type: "alert" }) }
      end
    end
  end

  def destroy
    @wishlist_item = current_user.wishlist_items.find(params[:id])
    @product = @wishlist_item.product
    @wishlist_item.destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: wishlist_items_path, notice: "Removed from wishlist" }
      format.turbo_stream
    end
  end
end
