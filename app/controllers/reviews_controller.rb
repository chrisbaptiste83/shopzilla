# frozen_string_literal: true

class ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_product

  def create
    @review = @product.reviews.build(review_params)
    @review.user = current_user

    if @review.save
      redirect_to product_path(@product), notice: "Thank you for your review!"
    else
      redirect_to product_path(@product), alert: @review.errors.full_messages.to_sentence
    end
  end

  def destroy
    @review = current_user.reviews.find_by(id: params[:id], product_id: @product.id)
    if @review&.destroy
      redirect_to product_path(@product), notice: "Review removed."
    else
      redirect_to product_path(@product), alert: "Could not remove review."
    end
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end

  def review_params
    params.require(:review).permit(:rating, :content)
  end
end
