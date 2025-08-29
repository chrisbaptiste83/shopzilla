ActiveAdmin.register Payment do
  permit_params :order_id, :amount, :stripe_payment_id, :status
  
  index do
    selectable_column
    id_column
    column :order
    column :amount do |payment|
      number_to_currency(payment.amount)
    end
    column :stripe_payment_id
    column :status
    column :created_at
    actions
  end
  
  filter :order
  filter :amount
  filter :status
  filter :stripe_payment_id
  filter :created_at
  
  show do
    attributes_table do
      row :order
      row :amount do |payment|
        number_to_currency(payment.amount)
      end
      row :stripe_payment_id
      row :status
      row :created_at
      row :updated_at
    end
    active_admin_comments
  end
end
