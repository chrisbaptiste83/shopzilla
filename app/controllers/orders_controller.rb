class OrdersController < ApplicationController
  before_action :authenticate_user!

  def index
    @orders = current_user.orders.includes(order_items: { product: [ :images_attachments, :category ] }).order(created_at: :desc)
    respond_to do |format|
      format.html
      format.json { render json: @orders.map { |o| order_json(o) } }
    end
  end

  def show
    @order = current_user.orders.includes(order_items: { product: [ :images_attachments, :category ] }).find(params[:id])
    respond_to do |format|
      format.html
      format.json { render json: order_json(@order) }
    end
  end

  def create
    items_attrs = order_params[:line_items_attributes] || []
    products    = Product.where(id: items_attrs.map { |i| i[:product_id] })
    total       = items_attrs.sum { |i| (products.find { |p| p.id.to_s == i[:product_id].to_s }&.price || 0) * i[:quantity].to_i }

    @order = current_user.orders.build(
      status: "pending",
      total: total
    )

    if @order.save
      items_attrs.each do |item|
        product = products.find { |p| p.id.to_s == item[:product_id].to_s }
        next unless product
        @order.order_items.create!(product: product, quantity: item[:quantity].to_i, unit_price: product.price)
      end
      render json: { order: order_json(@order) }, status: :created
    else
      render json: { errors: @order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def order_params
    params.require(:order).permit(line_items_attributes: [ :product_id, :quantity ])
  end

  def order_json(order)
    {
      id:         order.id,
      status:     order.status,
      total:      order.total,
      created_at: order.created_at,
      items:      order.order_items.map { |i|
        { product_id: i.product_id, quantity: i.quantity, unit_price: i.unit_price }
      }
    }
  end
end
