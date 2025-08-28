ActiveAdmin.register Order do
  permit_params :user_id, :total, :status, :shipping_address

  index do
    selectable_column
    id_column
    column :user
    column :total do |order|
      number_to_currency(order.total)
    end
    column :status
    column :created_at
    actions
  end

  filter :user
  filter :status
  filter :total
  filter :created_at

  show do
    attributes_table do
      row :user
      row :total do |order|
        number_to_currency(order.total)
      end
      row :status
      row :shipping_address
      row :created_at
      row :updated_at
    end

    panel "Order Items" do
      table_for order.order_items do
        column :product
        column :quantity
        column :unit_price do |item|
          number_to_currency(item.unit_price)
        end
      end
    end

    panel "Payment" do
      if order.payment
        attributes_table_for order.payment do
          row :amount do |payment|
            number_to_currency(payment.amount)
          end
          row :stripe_payment_id
          row :status
          row :created_at
        end
      else
        "No payment record"
      end
    end

    active_admin_comments
  end
end
