module ApplicationHelper
  def in_wishlist?(product)
    return false unless user_signed_in?
    current_user.wishlist_items.exists?(product_id: product.id)
  end

  def wishlist_item_for(product)
    return nil unless user_signed_in?
    current_user.wishlist_items.find_by(product_id: product.id)
  end
end
