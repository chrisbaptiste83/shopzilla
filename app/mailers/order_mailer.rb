# frozen_string_literal: true

class OrderMailer < ApplicationMailer
  helper ActionView::Helpers::NumberHelper

  def customer_receipt(order_id)
    @order = Order.includes(order_items: :product, download_accesses: :product).find_by(id: order_id)
    return unless @order && @order.user

    @user = @order.user
    @order_items = @order.order_items
    @downloads = @order.download_accesses

    mail(
      to: @user.email,
      subject: "Your Gloria's Embroidery Receipt & Downloads (Order ##{@order.id})"
    )
  end

  def merchant_order_notification(order_id)
    @order = Order.includes(:user, order_items: :product).find_by(id: order_id)
    return unless @order

    @user = @order.user
    recipient = ENV.fetch("MERCHANT_ORDER_NOTIFICATION_EMAIL", ENV.fetch("MERCHANT_SUPPORT_EMAIL", "support@gloriasembroideryshop.com"))

    mail(
      to: recipient,
      subject: "[Gloria's Embroidery Sale] Order ##{@order.id} - #{ActionController::Base.helpers.number_to_currency(@order.total)}"
    )
  end
end
