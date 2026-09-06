# frozen_string_literal: true

class CheckoutCompletionService
  class << self
    def complete_from_checkout_session(session)
      metadata = session["metadata"] || {}
      user = User.find_by(id: metadata["user_id"])
      return unless user

      return if Order.exists?(stripe_session_id: session["id"])

      order = ActiveRecord::Base.transaction do
        order = if metadata["order_id"].present?
          existing_order = Order.find(metadata["order_id"])
          existing_order.update!(
            status: "completed",
            stripe_session_id: session["id"]
          )
          existing_order
        else
          Order.create!(
            user: user,
            total: session["amount_total"].to_f / 100.0,
            status: "completed",
            stripe_session_id: session["id"]
          )
        end

        quantities_by_product_id = extract_quantities(metadata)
        product_ids = quantities_by_product_id.keys.map(&:to_i)
        if product_ids.empty? && metadata["product_ids"].present?
          product_ids = metadata["product_ids"].to_s.split(",").map(&:to_i)
        end
        products = Product.where(id: product_ids)

        Payment.create!(
          order: order,
          amount: session["amount_total"].to_f / 100.0,
          stripe_payment_id: session["payment_intent"],
          status: "completed"
        )

        products.each do |product|
          quantity = quantities_by_product_id.fetch(product.id.to_s, 1).to_i
          OrderItem.create!(
            order: order,
            product: product,
            quantity: quantity,
            unit_price: product.price
          )

          unless product.physical_product
            DownloadAccess.create!(
              user: user,
              product: product,
              order: order,
              expires_at: 30.days.from_now,
              download_count: 0
            )
          end
        end

        order
      end

      if order
        OrderMailer.customer_receipt(order.id).deliver_later
        OrderMailer.merchant_order_notification(order.id).deliver_later
      end

      order
    end

    def complete_from_payment_intent(intent)
      metadata = intent["metadata"] || {}
      return unless metadata["tap_to_pay"] == "true" || metadata["user_id"].present?

      user = User.find_by(id: metadata["user_id"])
      return unless user
      return if Payment.exists?(stripe_payment_id: intent["id"])

      order = ActiveRecord::Base.transaction do
        order = Order.create!(
          user: user,
          total: intent["amount"].to_f / 100.0,
          status: "completed",
          stripe_session_id: intent["id"]
        )

        Payment.create!(
          order: order,
          amount: intent["amount"].to_f / 100.0,
          stripe_payment_id: intent["id"],
          status: "completed"
        )

        product_ids = metadata["product_ids"].to_s.split(",").map(&:to_i)
        Product.where(id: product_ids).each do |product|
          OrderItem.create!(
            order: order,
            product: product,
            quantity: 1,
            unit_price: product.price
          )

          unless product.physical_product
            DownloadAccess.create!(
              user: user,
              product: product,
              order: order,
              expires_at: 30.days.from_now,
              download_count: 0
            )
          end
        end

        order
      end

      if order
        OrderMailer.customer_receipt(order.id).deliver_later
        OrderMailer.merchant_order_notification(order.id).deliver_later
      end

      order
    end

    private

    def extract_quantities(metadata)
      raw_quantities = metadata["product_quantities"]
      return {} if raw_quantities.blank?

      JSON.parse(raw_quantities)
    rescue JSON::ParserError
      {}
    end
  end
end
